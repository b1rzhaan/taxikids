"""Stripe Checkout adapter for test/demo card payments.

This adapter is intentionally positioned as a demo provider for this project:
Stripe Checkout is excellent for showing a real hosted card flow with test
cards, while Kazakhstan production acquiring can later be handled by Halyk,
ioka, Kaspi Pay, or another local adapter under the same PaymentProvider port.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import time
from decimal import Decimal, ROUND_HALF_UP
from urllib.parse import parse_qs

import requests
from django.conf import settings

from .base import PaymentIntent, PaymentProvider, WebhookEvent


class StripeError(ValueError):
    pass


class StripeProvider(PaymentProvider):
    name = "stripe"
    api_base = "https://api.stripe.com/v1"
    zero_decimal = {
        "bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga",
        "pyg", "rwf", "ugx", "vnd", "vuv", "xaf", "xof", "xpf",
    }

    def _secret_key(self) -> str:
        key = settings.STRIPE_SECRET_KEY
        if not key:
            raise StripeError("STRIPE_SECRET_KEY is not configured")
        return key

    def _request(self, method: str, path: str, **kwargs) -> dict:
        try:
            resp = requests.request(
                method,
                f"{self.api_base}{path}",
                auth=(self._secret_key(), ""),
                timeout=20,
                **kwargs,
            )
            resp.raise_for_status()
            return resp.json()
        except (requests.RequestException, ValueError) as exc:
            raise StripeError(str(exc)) from exc

    def create_payment(self, trip, amount, currency, idempotency_key) -> PaymentIntent:
        stripe_currency = settings.STRIPE_CURRENCY.lower()
        amount_minor, display_amount = self._amount_for_stripe(amount, currency)
        data = {
            "mode": "payment",
            "client_reference_id": str(trip.id),
            "success_url": settings.STRIPE_SUCCESS_URL,
            "cancel_url": settings.STRIPE_CANCEL_URL,
            "payment_method_types[0]": "card",
            "line_items[0][quantity]": "1",
            "line_items[0][price_data][currency]": stripe_currency,
            "line_items[0][price_data][unit_amount]": str(amount_minor),
            "line_items[0][price_data][product_data][name]": f"KidsTaxi trip #{trip.id}",
            "line_items[0][price_data][product_data][description]": (
                f"{trip.pickup_text} -> {trip.dropoff_text}"
            )[:255],
            "metadata[trip_id]": str(trip.id),
            "metadata[idempotency_key]": idempotency_key,
            "metadata[source_amount]": str(amount),
            "metadata[source_currency]": str(currency),
        }
        session = self._request(
            "POST",
            "/checkout/sessions",
            data=data,
            headers={"Idempotency-Key": idempotency_key},
        )
        extra = {
            "session_id": session["id"],
            "url": session.get("url", ""),
            "success_url": settings.STRIPE_SUCCESS_URL,
            "success_prefix": settings.STRIPE_SUCCESS_URL.split("?")[0],
            "cancel_url": settings.STRIPE_CANCEL_URL,
            "cancel_prefix": settings.STRIPE_CANCEL_URL.split("?")[0],
            "stripe_currency": stripe_currency,
            "stripe_amount_minor": amount_minor,
            "display_amount": str(display_amount),
            "demo_note": "Stripe is used for test/demo payments only.",
        }
        return PaymentIntent(
            provider_ref=session["id"],
            status="pending",
            redirect_url=session.get("url", ""),
            extra=extra,
        )

    def verify_status(self, session_id: str) -> str:
        session = self._request("GET", f"/checkout/sessions/{session_id}")
        payment_status = session.get("payment_status")
        status = session.get("status")
        if payment_status == "paid":
            return "success"
        if status == "expired":
            return "failed"
        return "pending"

    def verify_webhook(self, request) -> WebhookEvent:
        payload = request.body or b"{}"
        self._verify_signature(payload, request.headers.get("Stripe-Signature", ""))
        try:
            event = json.loads(payload.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError("Invalid Stripe webhook payload") from exc

        event_type = event.get("type", "")
        obj = event.get("data", {}).get("object", {})
        provider_ref = obj.get("id", "")
        if event_type == "checkout.session.completed":
            status = "success" if obj.get("payment_status") == "paid" else "pending"
        elif event_type in ("checkout.session.expired", "payment_intent.payment_failed"):
            provider_ref = provider_ref or obj.get("metadata", {}).get("session_id", "")
            status = "failed"
        else:
            status = "pending"
        return WebhookEvent(provider_ref=provider_ref, status=status, raw=event)

    def refund(self, payment) -> bool:
        session = self._request("GET", f"/checkout/sessions/{payment.provider_ref}")
        payment_intent = session.get("payment_intent")
        if not payment_intent:
            return False
        refund = self._request(
            "POST",
            "/refunds",
            data={"payment_intent": payment_intent},
        )
        return refund.get("status") in ("succeeded", "pending", "requires_action")

    def _amount_for_stripe(self, amount, source_currency: str) -> tuple[int, Decimal]:
        target = settings.STRIPE_CURRENCY.lower()
        value = Decimal(str(amount))
        if source_currency.upper() == "KZT" and target != "kzt":
            rate = Decimal(str(settings.STRIPE_DEMO_KZT_TO_TARGET_RATE))
            if rate <= 0:
                raise StripeError("STRIPE_DEMO_KZT_TO_TARGET_RATE must be positive")
            value = (value / rate).quantize(Decimal("0.01"), ROUND_HALF_UP)
        if target in self.zero_decimal:
            minor = int(value.quantize(Decimal("1"), ROUND_HALF_UP))
        else:
            minor = int((value * Decimal("100")).quantize(Decimal("1"), ROUND_HALF_UP))
        return max(minor, 50), value

    def _verify_signature(self, payload: bytes, header: str) -> None:
        secret = settings.STRIPE_WEBHOOK_SECRET
        if not secret:
            if settings.DEBUG:
                return
            raise ValueError("STRIPE_WEBHOOK_SECRET is not configured")

        parts = {k: v for k, vals in parse_qs(header.replace(",", "&")).items()
                 for v in vals}
        timestamp = parts.get("t")
        signature = parts.get("v1")
        if not timestamp or not signature:
            raise ValueError("Missing Stripe signature")
        if abs(time.time() - int(timestamp)) > 300:
            raise ValueError("Stale Stripe signature")
        signed = f"{timestamp}.".encode("utf-8") + payload
        expected = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, signature):
            raise ValueError("Invalid Stripe signature")
