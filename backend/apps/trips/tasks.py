"""Scheduled generation of concrete Trips from recurring plans.

Run daily (Celery beat) to materialise tomorrow's trips, or invoke the
management command `generate_recurring_trips` manually / from cron."""
from __future__ import annotations

import datetime as dt

from celery import shared_task
from django.utils import timezone

from .models import RecurringTripPlan, Trip, TripStatus
from .services import build_route_for_trip


def generate_for_date(target: dt.date) -> int:
    weekday = target.weekday()
    created = 0
    plans = RecurringTripPlan.objects.filter(
        is_active=True, valid_from__lte=target
    ).select_related("child", "parent", "tariff")
    for plan in plans:
        if plan.valid_to and plan.valid_to < target:
            continue
        if weekday not in plan.weekdays:
            continue
        scheduled_at = timezone.make_aware(
            dt.datetime.combine(target, plan.pickup_time)
        )
        # Idempotency: one trip per plan per day.
        if Trip.objects.filter(plan=plan, scheduled_at=scheduled_at).exists():
            continue
        trip = Trip(
            plan=plan,
            parent=plan.parent,
            child=plan.child,
            pickup_text=plan.pickup_text,
            pickup_lat=plan.pickup_lat,
            pickup_lng=plan.pickup_lng,
            dropoff_text=plan.dropoff_text,
            dropoff_lat=plan.dropoff_lat,
            dropoff_lng=plan.dropoff_lng,
            scheduled_at=scheduled_at,
            tariff=plan.tariff,
            status=TripStatus.CREATED,
        )
        build_route_for_trip(trip)
        trip.save()
        created += 1
    return created


@shared_task
def generate_recurring_trips(days_ahead: int = 1) -> int:
    target = timezone.localdate() + dt.timedelta(days=days_ahead)
    return generate_for_date(target)
