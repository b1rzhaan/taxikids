"""Notification fan-out. In MVP we persist in-app notifications and stub FCM;
swapping in real Firebase later means implementing `_send_push` only."""
from __future__ import annotations

from .models import Notification

# Human-readable messages per trip status for the parent.
_STATUS_MESSAGES = {
    "driver_assigned": ("Водитель назначен", "Водитель назначен на поездку вашего ребёнка"),
    "driver_on_way": ("Водитель выехал", "Водитель уже в пути к вам"),
    "driver_arrived": ("Водитель прибыл", "Водитель ждёт у места отправления"),
    "child_picked_up": ("Ребёнок забран", "Ребёнок сел в машину"),
    "in_progress": ("Поездка началась", "Ребёнок в пути"),
    "child_delivered": ("Ребёнок доставлен", "Ребёнок прибыл в место назначения"),
    "completed": ("Поездка завершена", "Спасибо, что пользуетесь сервисом"),
    "cancelled": ("Поездка отменена", "Поездка была отменена"),
}


def create_notification(user, ntype, title, body="", data=None, channel="inapp"):
    notif = Notification.objects.create(
        user=user, type=ntype, title=title, body=body,
        data=data or {}, channel=channel,
    )
    _send_push(notif)
    return notif


def notify_trip_status(trip, status: str) -> None:
    msg = _STATUS_MESSAGES.get(status)
    if not msg:
        return
    title, body = msg
    data = {"trip_id": trip.id, "status": status}

    # Notify the parent.
    parent_user = getattr(trip.parent, "user", None)
    if parent_user:
        create_notification(parent_user, f"trip_{status}", title, body, data, "push")

    # Notify the driver on assignment.
    if status == "driver_assigned" and trip.driver and trip.driver.user:
        create_notification(
            trip.driver.user, "trip_assigned",
            "Новый заказ", "Вам назначена новая поездка", data, "push",
        )


def _send_push(notification) -> None:
    """Stub. Replace with Firebase Admin SDK call for real push delivery."""
    notification.fcm_status = "stub_sent"
    notification.save(update_fields=["fcm_status"])
