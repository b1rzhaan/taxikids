from django.db import models

from apps.accounts.models import User


class Notification(models.Model):
    class Channel(models.TextChoices):
        PUSH = "push", "Push"
        INAPP = "inapp", "In-app"

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="notifications"
    )
    type = models.CharField(max_length=40)
    title = models.CharField(max_length=140)
    body = models.CharField(max_length=255, blank=True)
    data = models.JSONField(default=dict, blank=True)
    channel = models.CharField(max_length=10, choices=Channel.choices, default=Channel.INAPP)
    is_read = models.BooleanField(default=False)
    fcm_status = models.CharField(max_length=20, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]


class DeviceToken(models.Model):
    class Platform(models.TextChoices):
        ANDROID = "android", "Android"
        IOS = "ios", "iOS"

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="devices"
    )
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=10, choices=Platform.choices)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "device_tokens"


class EmergencyRequest(models.Model):
    class Type(models.TextChoices):
        SOS = "sos", "SOS"
        CALL = "call_request", "Запрос звонка"
        COMPLAINT = "complaint", "Жалоба"

    class Status(models.TextChoices):
        OPEN = "open", "Открыт"
        IN_PROGRESS = "in_progress", "В работе"
        RESOLVED = "resolved", "Решён"

    trip = models.ForeignKey(
        "trips.Trip", on_delete=models.SET_NULL, null=True, blank=True
    )
    created_by = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="emergency_requests"
    )
    type = models.CharField(max_length=16, choices=Type.choices, default=Type.SOS)
    message = models.TextField(blank=True)
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.OPEN
    )
    handled_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="handled_emergencies",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "emergency_requests"
        ordering = ["-created_at"]


class SupportThread(models.Model):
    class Status(models.TextChoices):
        OPEN = "open", "Открыт"
        IN_PROGRESS = "in_progress", "В работе"
        RESOLVED = "resolved", "Решен"

    participant = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="support_threads"
    )
    trip = models.ForeignKey(
        "trips.Trip",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="support_threads",
    )
    assigned_to = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_support_threads",
    )
    subject = models.CharField(max_length=160, blank=True)
    status = models.CharField(
        max_length=16, choices=Status.choices, default=Status.OPEN
    )
    last_message_at = models.DateTimeField(auto_now_add=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "support_threads"
        ordering = ["-last_message_at", "-created_at"]

    def __str__(self) -> str:
        return self.subject or f"Support #{self.pk}"


class SupportMessage(models.Model):
    class SenderRole(models.TextChoices):
        PARENT = "parent", "Родитель"
        DRIVER = "driver", "Водитель"
        OPERATOR = "operator", "Оператор"
        ADMIN = "admin", "Администратор"
        ACCOUNTANT = "accountant", "Бухгалтер"
        AI = "ai", "AI"
        SYSTEM = "system", "Система"

    thread = models.ForeignKey(
        SupportThread, on_delete=models.CASCADE, related_name="messages"
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="support_messages",
    )
    sender_role = models.CharField(max_length=16, choices=SenderRole.choices)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "support_messages"
        ordering = ["created_at"]
