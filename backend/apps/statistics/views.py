import datetime as dt

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDay
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from apps.accounts.models import Role
from apps.accounts.permissions import IsStaffRole
from apps.children.models import Child
from apps.drivers.models import DriverProfile
from apps.payments.models import Payment
from apps.payouts.models import DriverEarning, Payout
from apps.trips.models import Trip, TripStatus

ACTIVE_STATUSES = [
    TripStatus.DRIVER_ASSIGNED, TripStatus.DRIVER_ON_WAY,
    TripStatus.DRIVER_ARRIVED, TripStatus.CHILD_PICKED_UP,
    TripStatus.IN_PROGRESS, TripStatus.CHILD_DELIVERED,
]


def _revenue_since(since: dt.date):
    return Payment.objects.filter(
        status=Payment.Status.SUCCESS, paid_at__date__gte=since
    ).aggregate(s=Sum("amount"))["s"] or 0


def _trips_by_day(days: int = 30):
    """Daily series for the dashboard chart: trips, completed, revenue."""
    since = timezone.localdate() - dt.timedelta(days=days - 1)
    by_day = {
        (since + dt.timedelta(days=i)).isoformat(): {
            "day": (since + dt.timedelta(days=i)).isoformat(),
            "trips": 0,
            "completed": 0,
            "revenue": 0.0,
        }
        for i in range(days)
    }
    trip_rows = (
        Trip.objects.filter(scheduled_at__date__gte=since)
        .annotate(day=TruncDay("scheduled_at"))
        .values("day")
        .annotate(
            trips=Count("id"),
            completed=Count("id", filter=Q(status=TripStatus.COMPLETED)),
        )
    )
    for r in trip_rows:
        key = r["day"].date().isoformat()
        if key in by_day:
            by_day[key]["trips"] = r["trips"]
            by_day[key]["completed"] = r["completed"]
    pay_rows = (
        Payment.objects.filter(
            status=Payment.Status.SUCCESS, paid_at__date__gte=since
        )
        .annotate(day=TruncDay("paid_at"))
        .values("day")
        .annotate(total=Sum("amount"))
    )
    for r in pay_rows:
        key = r["day"].date().isoformat()
        if key in by_day:
            by_day[key]["revenue"] = float(r["total"] or 0)
    return list(by_day.values())


def _top_drivers(limit: int = 5):
    rows = (
        DriverProfile.objects.annotate(
            trips_count=Count("trips", filter=Q(trips__status=TripStatus.COMPLETED))
        )
        .values("id", "full_name", "phone", "rating", "trips_count")
        .order_by("-rating", "-trips_count")[:limit]
    )
    return list(rows)


@api_view(["GET"])
@permission_classes([IsStaffRole])
def dashboard(request):
    today = timezone.localdate()
    week_ago = today - dt.timedelta(days=7)
    month_ago = today - dt.timedelta(days=30)

    trips = Trip.objects.all()
    revenue_total = (
        Payment.objects.filter(status=Payment.Status.SUCCESS)
        .aggregate(s=Sum("amount"))["s"] or 0
    )
    driver_expense = (
        DriverEarning.objects.aggregate(s=Sum("amount"))["s"] or 0
    )

    return Response({
        "trips_total": trips.count(),
        "trips_active": trips.filter(status__in=ACTIVE_STATUSES).count(),
        "trips_completed": trips.filter(status=TripStatus.COMPLETED).count(),
        "trips_cancelled": trips.filter(status=TripStatus.CANCELLED).count(),
        "clients_count": Child.objects.values("parent").distinct().count(),
        "children_count": Child.objects.count(),
        "drivers_count": DriverProfile.objects.count(),
        "revenue": {
            "total": revenue_total,
            "today": _revenue_since(today),
            "week": _revenue_since(week_ago),
            "month": _revenue_since(month_ago),
        },
        # Owner panel figures (see mockups): app income vs driver expense.
        "driver_expense_total": driver_expense,
        "app_income_total": float(revenue_total) - float(driver_expense),
        "payouts_pending": Payout.objects.filter(
            status=Payout.Status.PENDING
        ).aggregate(s=Sum("total_amount"))["s"] or 0,
        # Series + leaderboard for the dashboard redesign.
        "trips_by_day": _trips_by_day(30),
        "top_drivers": _top_drivers(5),
    })


@api_view(["GET"])
@permission_classes([IsStaffRole])
def revenue(request):
    period = request.query_params.get("period", "week")
    days = {"day": 1, "week": 7, "month": 30}.get(period, 7)
    since = timezone.localdate() - dt.timedelta(days=days)
    rows = (
        Payment.objects.filter(status=Payment.Status.SUCCESS, paid_at__date__gte=since)
        .annotate(day=TruncDay("paid_at"))
        .values("day")
        .annotate(total=Sum("amount"), count=Count("id"))
        .order_by("day")
    )
    return Response(list(rows))


@api_view(["GET"])
@permission_classes([IsStaffRole])
def drivers_stats(request):
    rows = (
        DriverProfile.objects.annotate(
            trips_completed=Count(
                "trips", filter=None
            ),
            earned=Sum("earnings__amount"),
        )
        .values("id", "full_name", "rating", "trips_completed", "earned")
        .order_by("-earned")
    )
    return Response(list(rows))
