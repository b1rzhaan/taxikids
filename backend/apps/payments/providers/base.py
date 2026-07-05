"""Port (interface) for payment providers.

Concrete adapters (Mock, Kaspi, Halyk, Stripe) implement PaymentProvider.
The system creates an intent, redirects the user to the provider, then the
provider confirms asynchronously via a signed webhook — exactly like a real
bank integration, so swapping Mock → Kaspi requires no changes elsewhere."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class PaymentIntent:
    provider_ref: str
    status: str              # pending | success | failed
    redirect_url: str = ""   # where to send the payer (hosted payment page)
    extra: dict | None = None  # provider-specific data (e.g. Halyk widget object)


@dataclass
class WebhookEvent:
    provider_ref: str
    status: str              # success | failed | refunded
    amount: str | None = None
    raw: dict | None = None


class PaymentProvider(ABC):
    name: str = "base"

    @abstractmethod
    def create_payment(self, trip, amount, currency, idempotency_key) -> PaymentIntent:
        ...

    @abstractmethod
    def verify_webhook(self, request) -> WebhookEvent:
        """Validate signature and parse the provider's callback."""

    @abstractmethod
    def refund(self, payment) -> bool:
        ...
