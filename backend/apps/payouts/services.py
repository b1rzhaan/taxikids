"""Aggregate a driver's accrued earnings for a period into a single payout."""
from __future__ import annotations

import datetime as dt
from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from .models import DriverEarning, Payout, PayoutItem


@transaction.atomic
def create_payout(driver, period_start: dt.date, period_end: dt.date, actor) -> Payout:
    earnings = DriverEarning.objects.select_for_update().filter(
        driver=driver,
        status=DriverEarning.Status.ACCRUED,
        created_at__date__gte=period_start,
        created_at__date__lte=period_end,
    )
    total = earnings.aggregate(s=Sum("amount"))["s"] or Decimal("0")
    payout = Payout.objects.create(
        driver=driver,
        period_start=period_start,
        period_end=period_end,
        total_amount=total,
        created_by=actor if getattr(actor, "pk", None) else None,
    )
    items = [PayoutItem(payout=payout, earning=e) for e in earnings]
    PayoutItem.objects.bulk_create(items)
    earnings.update(status=DriverEarning.Status.INCLUDED)
    return payout


@transaction.atomic
def mark_paid(payout: Payout) -> Payout:
    payout.status = Payout.Status.PAID
    payout.paid_at = timezone.now()
    payout.save(update_fields=["status", "paid_at"])
    return payout
