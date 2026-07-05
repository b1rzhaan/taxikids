"""Payment orchestration: provider factory + create/confirm/refund flows."""
from __future__ import annotations

import uuid
from functools import lru_cache

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.trips.models import PaymentStatus as TripPaymentStatus
from apps.trips.models import Trip, TripStatus
from apps.trips.services import TripService

from .models import Payment
from .providers.base import PaymentProvider
from .providers.mock import MockPaymentProvider


@lru_cache(maxsize=None)
def get_payment_provider() -> PaymentProvider:
    provider = settings.PAYMENT_PROVIDER.lower()
    if provider == "halyk":
        from .providers.halyk import HalykProvider

        return HalykProvider()
    return MockPaymentProvider()


@transaction.atomic
def create_payment_for_trip(trip: Trip) -> tuple[Payment, str]:
    """Create a pending Payment + provider intent, move trip to waiting_payment."""
    if trip.payment_status == TripPaymentStatus.PAID:
        raise ValueError("Trip already paid")

    provider = get_payment_provider()
    idem = uuid.uuid4().hex
    intent = provider.create_payment(
        trip, trip.price_amount, trip.price_currency, idem
    )
    payment = Payment.objects.create(
        trip=trip,
        parent=trip.parent,
        provider=provider.name,
        provider_ref=intent.provider_ref,
        amount=trip.price_amount,
        currency=trip.price_currency,
        status=Payment.Status.PENDING,
        idempotency_key=idem,
        raw_payload=intent.extra or {},
    )
    trip.payment_status = TripPaymentStatus.PENDING
    trip.save(update_fields=["payment_status"])
    if trip.status == TripStatus.CREATED:
        TripService.transition(trip, "request_payment", actor=None)
    return payment, intent.redirect_url


@transaction.atomic
def confirm_payment(provider_ref: str, event_status: str, raw: dict | None = None):
    """Apply a webhook result. Idempotent on provider_ref."""
    payment = (
        Payment.objects.select_for_update()
        .filter(provider_ref=provider_ref)
        .first()
    )
    if payment is None:
        return None
    if payment.status in (Payment.Status.SUCCESS, Payment.Status.REFUNDED):
        return payment  # already processed

    payment.raw_payload = raw or {}
    if event_status == "success":
        payment.status = Payment.Status.SUCCESS
        payment.paid_at = timezone.now()
        payment.save(update_fields=["status", "paid_at", "raw_payload"])
        trip = payment.trip
        if trip.status in (TripStatus.CREATED, TripStatus.WAITING_PAYMENT):
            TripService.transition(trip, "pay_success", actor=None)
    else:
        payment.status = Payment.Status.FAILED
        payment.save(update_fields=["status", "raw_payload"])
        trip = payment.trip
        trip.payment_status = TripPaymentStatus.FAILED
        trip.save(update_fields=["payment_status"])
    return payment


def refund_trip(trip: Trip) -> bool:
    provider = get_payment_provider()
    payment = trip.payments.filter(status=Payment.Status.SUCCESS).first()
    if not payment:
        return False
    if provider.refund(payment):
        payment.status = Payment.Status.REFUNDED
        payment.save(update_fields=["status"])
        return True
    return False
