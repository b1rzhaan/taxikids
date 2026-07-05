"""Halyk Bank ePay adapter (Kazakhstan card acquiring).

Real integration against Halyk's ePay:
  1. Get an OAuth token bound to the invoice (client_credentials).
  2. Hand the mobile app a `payment object` for Halyk's JS widget (halyk.pay).
  3. The widget shows the hosted card form (+3DS); on success it redirects to
     backLink and Halyk POSTs the result to postLink.
  4. We confirm server-side by querying the transaction status.

Defaults use Halyk's PUBLIC sandbox; set real HALYK_* env vars to go live.
Docs: https://developer.homebank.kz/epay
"""
from __future__ import annotations

import logging

import requests
from django.conf import settings

from .base import PaymentIntent, PaymentProvider, WebhookEvent

logger = logging.getLogger(__name__)


class HalykError(RuntimeError):
    pass


class HalykProvider(PaymentProvider):
    name = "halyk"

    def _token(self, invoice_id: str, amount, currency: str) -> dict:
        data = {
            "grant_type": "client_credentials",
            "scope": "webapi usermanagement email_send verification "
                     "statement statistics payment",
            "client_id": settings.HALYK_CLIENT_ID,
            "client_secret": settings.HALYK_CLIENT_SECRET,
            "invoiceID": invoice_id,
            "amount": str(amount),
            "currency": currency,
            "terminal": settings.HALYK_TERMINAL,
            "postLink": self._post_link(),
            "failurePostLink": self._post_link(),
        }
        try:
            resp = requests.post(settings.HALYK_OAUTH_URL, data=data, timeout=15)
            resp.raise_for_status()
            return resp.json()
        except (requests.RequestException, ValueError) as exc:
            logger.warning("Halyk token failed: %s", exc)
            raise HalykError(str(exc)) from exc

    def _post_link(self) -> str:
        # Public webhook; unreachable from localhost in dev (client confirm is used).
        base = settings.ALLOWED_HOSTS[0] if settings.ALLOWED_HOSTS else "localhost"
        return f"https://{base}/api/payments/webhook/halyk/"

    def build_widget(self, invoice_id, amount, currency, description, account_id):
        """Build the Halyk payment-widget object (with a bound OAuth token)."""
        amount_int = int(round(float(amount)))
        token = self._token(invoice_id, amount_int, currency)
        payment_object = {
            "invoiceId": invoice_id,
            "backLink": settings.HALYK_BACK_LINK,
            "failureBackLink": settings.HALYK_FAILURE_LINK,
            "postLink": self._post_link(),
            "failurePostLink": self._post_link(),
            "language": "RU",
            "description": description,
            "accountId": account_id,
            "terminal": settings.HALYK_TERMINAL,
            "amount": amount_int,
            "currency": currency,
            "auth": token,
        }
        return {"widget_js": settings.HALYK_WIDGET_JS, "payment": payment_object}

    def create_payment(self, trip, amount, currency, idempotency_key) -> PaymentIntent:
        # Halyk invoiceId must be numeric; derive a stable one from the key.
        # NOTE: the OAuth token is NOT fetched here — it's generated fresh when
        # the payment page is served, so it never expires before the form opens.
        invoice_id = str(int(idempotency_key[:12], 16))[:12].rjust(6, "0")
        extra = {
            "invoiceId": invoice_id,
            "amount": int(round(float(amount))),
            "currency": currency,
            "description": f"Оплата поездки №{trip.id}",
            "accountId": f"parent-{trip.parent_id}",
            "backLink": settings.HALYK_BACK_LINK,
            "failureBackLink": settings.HALYK_FAILURE_LINK,
        }
        return PaymentIntent(
            provider_ref=invoice_id, status="pending", redirect_url="", extra=extra)

    def verify_status(self, invoice_id: str) -> str:
        """Query transaction status → 'success' | 'failed' | 'pending'."""
        try:
            token = self._token(invoice_id, 0, "KZT").get("access_token")
            resp = requests.get(
                f"{settings.HALYK_API_URL}/check-status/payment/transaction/{invoice_id}",
                headers={"Authorization": f"Bearer {token}"},
                timeout=15,
            )
            if resp.status_code != 200:
                return "pending"
            data = resp.json()
            trans = (data.get("transaction") or {})
            status = (trans.get("statusName") or data.get("resultCode") or "").upper()
            if status in ("AUTH", "CHARGE", "OK", "PAID", "SUCCESS", "100"):
                return "success"
            if status in ("REJECT", "FAILED", "CANCEL"):
                return "failed"
            return "pending"
        except Exception as exc:  # noqa: BLE001
            logger.warning("Halyk status check failed: %s", exc)
            return "pending"

    def verify_webhook(self, request) -> WebhookEvent:
        import json

        payload = request.data if isinstance(request.data, dict) else json.loads(
            request.body or b"{}")
        code = str(payload.get("code", payload.get("resultCode", "")))
        ok = code in ("ok", "0", "100") or payload.get("status") == "ok"
        return WebhookEvent(
            provider_ref=str(payload.get("invoiceId", "")),
            status="success" if ok else "failed",
            amount=str(payload.get("amount")) if payload.get("amount") else None,
            raw=payload,
        )

    def refund(self, payment) -> bool:
        try:
            token = self._token(payment.provider_ref, int(payment.amount),
                                 payment.currency).get("access_token")
            resp = requests.post(
                f"{settings.HALYK_API_URL}/operation/{payment.provider_ref}/refund",
                headers={"Authorization": f"Bearer {token}"},
                params={"amount": int(payment.amount)},
                timeout=15,
            )
            return resp.status_code == 200
        except Exception:  # noqa: BLE001
            return False
