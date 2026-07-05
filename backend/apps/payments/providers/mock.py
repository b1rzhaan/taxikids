"""Mock payment provider: emulates a hosted payment page + webhook so the
whole payment flow works end-to-end without any bank contract.

The 'redirect_url' points at our own demo endpoint that lets you click
Success/Fail; that endpoint calls back into the webhook, just like a real PSP."""
from __future__ import annotations

import hashlib
import hmac
import json
import uuid

from django.conf import settings

from .base import PaymentIntent, PaymentProvider, WebhookEvent


class MockPaymentProvider(PaymentProvider):
    name = "mock"

    def create_payment(self, trip, amount, currency, idempotency_key) -> PaymentIntent:
        ref = f"mock_{uuid.uuid4().hex[:16]}"
        redirect = f"/api/payments/mock-checkout/?ref={ref}"
        return PaymentIntent(provider_ref=ref, status="pending", redirect_url=redirect)

    def verify_webhook(self, request) -> WebhookEvent:
        payload = _load(request)
        signature = request.headers.get("X-Signature", "")
        expected = self._sign(payload)
        # In DEBUG we accept unsigned calls to ease manual testing.
        if not settings.DEBUG and not hmac.compare_digest(signature, expected):
            raise ValueError("Invalid webhook signature")
        return WebhookEvent(
            provider_ref=payload.get("ref", ""),
            status=payload.get("status", "failed"),
            amount=str(payload.get("amount")) if payload.get("amount") else None,
            raw=payload,
        )

    def refund(self, payment) -> bool:
        return True

    @staticmethod
    def _sign(payload: dict) -> str:
        secret = settings.PAYMENT_WEBHOOK_SECRET.encode()
        body = json.dumps(payload, sort_keys=True).encode()
        return hmac.new(secret, body, hashlib.sha256).hexdigest()


def _load(request) -> dict:
    if isinstance(request.data, dict):
        return request.data
    try:
        return json.loads(request.body or b"{}")
    except json.JSONDecodeError:
        return {}
