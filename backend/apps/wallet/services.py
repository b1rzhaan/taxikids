"""Wallet & subscription operations. All balance changes go through here so
every movement produces a WalletTransaction with a running balance snapshot."""
from __future__ import annotations

import datetime as dt
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from apps.accounts.models import ParentProfile

from .models import Subscription, SubscriptionPlan, Wallet, WalletTransaction


def get_or_create_wallet(parent: ParentProfile) -> Wallet:
    wallet, _ = Wallet.objects.get_or_create(parent=parent)
    return wallet


@transaction.atomic
def credit(parent: ParentProfile, amount: Decimal, kind: str, note: str = "", trip=None):
    wallet = Wallet.objects.select_for_update().get_or_create(parent=parent)[0]
    wallet.balance += Decimal(amount)
    wallet.save(update_fields=["balance", "updated_at"])
    return WalletTransaction.objects.create(
        wallet=wallet, kind=kind, amount=Decimal(amount),
        balance_after=wallet.balance, note=note, trip=trip,
    )


@transaction.atomic
def debit(parent: ParentProfile, amount: Decimal, kind: str, note: str = "", trip=None):
    wallet = Wallet.objects.select_for_update().get_or_create(parent=parent)[0]
    amount = Decimal(amount)
    if wallet.balance < amount:
        raise ValueError("Недостаточно средств на балансе")
    wallet.balance -= amount
    wallet.save(update_fields=["balance", "updated_at"])
    return WalletTransaction.objects.create(
        wallet=wallet, kind=kind, amount=-amount,
        balance_after=wallet.balance, note=note, trip=trip,
    )


@transaction.atomic
def buy_subscription(parent: ParentProfile, plan: SubscriptionPlan) -> Subscription:
    """MVP: charge the wallet immediately and activate the subscription."""
    debit(parent, plan.price, WalletTransaction.Kind.SUBSCRIPTION,
          note=f"Абонемент «{plan.name}»")
    return Subscription.objects.create(
        parent=parent,
        plan=plan,
        trips_total=plan.trips_count,
        valid_until=timezone.localdate() + dt.timedelta(days=plan.duration_days),
    )


@transaction.atomic
def create_topup(parent: ParentProfile, amount: Decimal):
    """Create a pending top-up using the configured demo/acquiring provider."""
    import uuid

    from django.conf import settings
    from apps.payments.services import get_payment_provider

    from .models import TopUpIntent

    amount = Decimal(amount)
    provider_name = settings.PAYMENT_PROVIDER.lower()
    if provider_name == "halyk":
        # Token is generated fresh when the page is served (see topup_halyk_page).
        invoice_id = str(int(uuid.uuid4().hex[:12], 16))[:12].rjust(6, "0")
        extra = {
            "invoiceId": invoice_id,
            "amount": int(amount),
            "currency": "KZT",
            "description": "Пополнение кошелька",
            "accountId": f"parent-{parent.id}",
            "backLink": settings.HALYK_BACK_LINK,
            "failureBackLink": settings.HALYK_FAILURE_LINK,
        }
        intent = TopUpIntent.objects.create(
            parent=parent, amount=amount, ref=invoice_id,
            provider="halyk", raw_payload=extra)
        return intent, ""

    if provider_name == "stripe":
        ref = f"tu_{uuid.uuid4().hex[:16]}"
        intent = TopUpIntent.objects.create(
            parent=parent,
            amount=amount,
            ref=ref,
            provider="stripe",
        )
        provider = get_payment_provider()
        checkout = provider.create_checkout(
            client_reference=ref,
            amount=amount,
            source_currency=settings.DEFAULT_CURRENCY,
            idempotency_key=ref,
            name="KidsTaxi wallet top-up",
            description="Пополнение кошелька Детское такси",
            metadata={
                "topup_ref": ref,
                "parent_id": str(parent.id),
                "source": "wallet_topup",
            },
        )
        intent.raw_payload = {
            **(checkout.extra or {}),
            "topup_ref": ref,
            "provider_ref": checkout.provider_ref,
        }
        intent.save(update_fields=["raw_payload"])
        return intent, checkout.redirect_url

    ref = f"tu_{uuid.uuid4().hex[:16]}"
    intent = TopUpIntent.objects.create(parent=parent, amount=amount, ref=ref)
    return intent, f"/api/wallet/topup/checkout/?ref={ref}"


@transaction.atomic
def confirm_topup(ref: str, success: bool):
    """Bank callback: credit the wallet on success. Idempotent by ref."""
    from .models import TopUpIntent

    intent = TopUpIntent.objects.select_for_update().filter(ref=ref).first()
    if intent is None:
        return None
    if intent.status != TopUpIntent.Status.PENDING:
        return intent  # already processed
    if success:
        intent.status = TopUpIntent.Status.SUCCESS
        intent.save(update_fields=["status"])
        credit(intent.parent, intent.amount, WalletTransaction.Kind.TOPUP,
               note="Пополнение картой")
    else:
        intent.status = TopUpIntent.Status.FAILED
        intent.save(update_fields=["status"])
    return intent


def active_subscription(parent: ParentProfile) -> Subscription | None:
    for sub in parent.subscriptions.filter(status=Subscription.Status.ACTIVE):
        if sub.is_usable:
            return sub
    return None
