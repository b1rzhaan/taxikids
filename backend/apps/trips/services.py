"""Trip state machine — the single source of truth for status changes.

Views never mutate Trip.status directly; they call TripService.transition(),
which validates the event against the current status AND the actor's role,
writes an audit record, fires notifications, and runs side effects
(driver earning on completion, refund on cancel)."""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from apps.accounts.models import Role

from .models import (
    PaymentMethod,
    PaymentStatus,
    Trip,
    TripStatus,
    TripStatusHistory,
)


class TripTransitionError(Exception):
    """Raised when an event is invalid for the trip's state or the actor."""


@dataclass(frozen=True)
class Transition:
    event: str
    from_statuses: tuple[str, ...]
    to_status: str
    roles: tuple[str, ...]  # roles allowed to trigger this event


# System role is used for automated transitions (payment webhook, scheduler).
SYSTEM = "system"

_MOVE_ROLES = (Role.DRIVER, Role.OPERATOR, Role.ADMIN)

TRANSITIONS: dict[str, Transition] = {
    t.event: t
    for t in [
        Transition("request_payment", (TripStatus.CREATED,),
                   TripStatus.WAITING_PAYMENT, (Role.PARENT, Role.OPERATOR, Role.ADMIN, SYSTEM)),
        Transition("pay_success", (TripStatus.CREATED, TripStatus.WAITING_PAYMENT),
                   TripStatus.PAID, (SYSTEM, Role.ADMIN)),
        # Cash: the order becomes assignable now; money is collected by the
        # driver at the end of the ride (settled on `complete`).
        Transition("confirm_cash", (TripStatus.CREATED, TripStatus.WAITING_PAYMENT),
                   TripStatus.PAID, (Role.PARENT, Role.OPERATOR, Role.ADMIN, SYSTEM)),
        Transition("assign", (TripStatus.PAID, TripStatus.DRIVER_ASSIGNED),
                   TripStatus.DRIVER_ASSIGNED, (Role.OPERATOR, Role.ADMIN)),
        Transition("depart", (TripStatus.DRIVER_ASSIGNED,),
                   TripStatus.DRIVER_ON_WAY, _MOVE_ROLES),
        Transition("arrive", (TripStatus.DRIVER_ON_WAY,),
                   TripStatus.DRIVER_ARRIVED, _MOVE_ROLES),
        Transition("pick_up", (TripStatus.DRIVER_ARRIVED,),
                   TripStatus.CHILD_PICKED_UP, _MOVE_ROLES),
        Transition("start", (TripStatus.CHILD_PICKED_UP,),
                   TripStatus.IN_PROGRESS, _MOVE_ROLES),
        Transition("deliver", (TripStatus.IN_PROGRESS,),
                   TripStatus.CHILD_DELIVERED, _MOVE_ROLES),
        Transition("complete", (TripStatus.CHILD_DELIVERED,),
                   TripStatus.COMPLETED, _MOVE_ROLES),
    ]
}

# Statuses from which a parent may still cancel their own trip.
PARENT_CANCELLABLE = {
    TripStatus.CREATED, TripStatus.WAITING_PAYMENT,
    TripStatus.PAID, TripStatus.DRIVER_ASSIGNED,
}
# Terminal statuses.
TERMINAL = {TripStatus.COMPLETED, TripStatus.CANCELLED}


class TripService:
    @staticmethod
    @transaction.atomic
    def transition(trip: Trip, event: str, actor, note: str = "", **kwargs) -> Trip:
        role = getattr(actor, "role", SYSTEM)

        if event == "cancel":
            return TripService._cancel(trip, actor, role, note)

        tr = TRANSITIONS.get(event)
        if tr is None:
            raise TripTransitionError(f"Unknown event '{event}'")
        if role not in tr.roles:
            raise TripTransitionError(f"Role '{role}' cannot '{event}'")
        if trip.status not in tr.from_statuses:
            raise TripTransitionError(
                f"Cannot '{event}' from status '{trip.status}'"
            )

        # A driver may only move their own assigned trips.
        if role == Role.DRIVER and trip.driver_id != getattr(
            getattr(actor, "driver_profile", None), "id", None
        ):
            raise TripTransitionError("Driver is not assigned to this trip")

        from_status = trip.status

        if event == "assign":
            TripService._apply_assignment(trip, kwargs)
        if event == "pay_success":
            trip.payment_status = PaymentStatus.PAID
        if event == "confirm_cash":
            # Order is confirmed and assignable; cash is still owed until the ride ends.
            trip.payment_method = PaymentMethod.CASH
            trip.payment_status = PaymentStatus.UNPAID
        if event == "complete":
            TripService._accrue_driver_earning(trip)
            TripService._settle_cash(trip)

        trip.status = tr.to_status
        trip.save(update_fields=["status", "payment_status", "payment_method",
                                 "driver", "vehicle",
                                 "driver_earning_amount", "updated_at"])
        TripService._record(trip, from_status, tr.to_status, event, actor, note)
        TripService._notify(trip, tr.to_status)
        return trip

    # ── Driver self-accept (Яндекс.Про-style) ────────────────────────
    @staticmethod
    @transaction.atomic
    def accept(trip: Trip, driver_user) -> Trip:
        """A driver takes a paid, unassigned order for themselves."""
        from apps.drivers.models import DriverProfile

        if trip.status != TripStatus.PAID:
            raise TripTransitionError("Заказ недоступен для принятия")
        if trip.driver_id is not None:
            raise TripTransitionError("Заказ уже принят другим водителем")
        driver = getattr(driver_user, "driver_profile", None)
        if driver is None:
            raise TripTransitionError("Только водитель может принять заказ")
        if driver.doc_status != DriverProfile.DocStatus.APPROVED:
            raise TripTransitionError("Ваши документы ещё не одобрены")

        trip.driver = driver
        trip.vehicle = driver.vehicles.filter(is_active=True).first()
        from_status = trip.status
        trip.status = TripStatus.DRIVER_ASSIGNED
        trip.save(update_fields=["driver", "vehicle", "status", "updated_at"])
        TripService._record(
            trip, from_status, TripStatus.DRIVER_ASSIGNED, "accept", driver_user, ""
        )
        TripService._notify(trip, TripStatus.DRIVER_ASSIGNED)
        return trip

    # ── Assignment ────────────────────────────────────────────────────
    @staticmethod
    def _apply_assignment(trip: Trip, kwargs: dict) -> None:
        from apps.drivers.models import DriverProfile, Vehicle

        driver_id = kwargs.get("driver_id")
        vehicle_id = kwargs.get("vehicle_id")
        if not driver_id:
            raise TripTransitionError("driver_id is required to assign")
        driver = DriverProfile.objects.filter(pk=driver_id).first()
        if driver is None:
            raise TripTransitionError("Driver not found")
        if driver.doc_status != DriverProfile.DocStatus.APPROVED:
            raise TripTransitionError("Driver documents are not approved")
        trip.driver = driver
        if vehicle_id:
            trip.vehicle = Vehicle.objects.filter(pk=vehicle_id).first()
        elif trip.vehicle is None:
            trip.vehicle = driver.vehicles.filter(is_active=True).first()

    # ── Cancellation + refund ─────────────────────────────────────────
    @staticmethod
    def _cancel(trip: Trip, actor, role: str, note: str) -> Trip:
        if trip.status in TERMINAL:
            raise TripTransitionError("Trip already finished")
        if role == Role.PARENT:
            if trip.parent.user_id != getattr(actor, "id", None):
                raise TripTransitionError("Not your trip")
            if trip.status not in PARENT_CANCELLABLE:
                raise TripTransitionError("Too late to cancel; call the operator")
        elif role not in (Role.OPERATOR, Role.ADMIN, SYSTEM):
            raise TripTransitionError(f"Role '{role}' cannot cancel")

        from_status = trip.status
        if trip.payment_status == PaymentStatus.PAID:
            trip.payment_status = PaymentStatus.REFUNDED
            TripService._refund(trip)
        trip.status = TripStatus.CANCELLED
        trip.save(update_fields=["status", "payment_status", "updated_at"])
        TripService._record(trip, from_status, TripStatus.CANCELLED, "cancel", actor, note)
        TripService._notify(trip, TripStatus.CANCELLED)
        return trip

    @staticmethod
    def _refund(trip: Trip) -> None:
        from apps.payments.services import refund_trip

        try:
            refund_trip(trip)
        except Exception:  # noqa: BLE001 — refund best-effort in MVP
            pass

    # ── Driver earning on completion ──────────────────────────────────
    @staticmethod
    def _accrue_driver_earning(trip: Trip) -> None:
        from django.conf import settings

        from apps.payouts.models import DriverEarning

        if trip.driver is None:
            return
        scheme = trip.driver.salary_scheme
        if scheme:
            amount = scheme.earning_for(trip.price_amount)
        else:
            amount = (trip.price_amount * Decimal(str(settings.DRIVER_REVENUE_SHARE))
                      ).quantize(Decimal("0.01"))
        trip.driver_earning_amount = amount
        DriverEarning.objects.get_or_create(
            trip=trip,
            defaults={"driver": trip.driver, "amount": amount},
        )

    # ── Cash settlement on completion ─────────────────────────────────
    @staticmethod
    def _settle_cash(trip: Trip) -> None:
        """Record the cash the driver collected so it lands in the DB and
        reconciles with revenue, exactly like a card payment."""
        import uuid

        from apps.payments.models import Payment

        if trip.payment_method != PaymentMethod.CASH:
            return
        if trip.payment_status == PaymentStatus.PAID:
            return
        Payment.objects.get_or_create(
            trip=trip,
            provider="cash",
            defaults={
                "parent": trip.parent,
                "provider_ref": f"cash_{trip.id}",
                "amount": trip.price_amount,
                "currency": trip.price_currency,
                "status": Payment.Status.SUCCESS,
                "idempotency_key": uuid.uuid4().hex,
                "paid_at": timezone.now(),
            },
        )
        trip.payment_status = PaymentStatus.PAID

    # ── Audit + notifications ─────────────────────────────────────────
    @staticmethod
    def _record(trip, from_status, to_status, event, actor, note):
        TripStatusHistory.objects.create(
            trip=trip,
            from_status=from_status,
            to_status=to_status,
            event=event,
            actor=actor if getattr(actor, "pk", None) else None,
            note=note,
        )

    @staticmethod
    def _notify(trip, to_status):
        from apps.notifications.services import notify_trip_status

        try:
            notify_trip_status(trip, to_status)
        except Exception:  # noqa: BLE001
            pass


def build_route_for_trip(trip: Trip) -> None:
    """Populate distance/duration/polyline/price using the map provider."""
    from apps.maps.providers.base import Point
    from apps.maps.services import safe_route

    route = safe_route(
        Point(trip.pickup_lat, trip.pickup_lng),
        Point(trip.dropoff_lat, trip.dropoff_lng),
    )
    trip.route_distance_m = route.distance_m
    trip.route_duration_s = route.duration_traffic_s
    trip.route_polyline = route.polyline
    if trip.tariff:
        trip.price_amount = trip.tariff.price_for(
            route.distance_m, route.duration_traffic_s
        )
