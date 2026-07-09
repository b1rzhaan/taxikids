import requests
from django.conf import settings
from django.utils import timezone
from rest_framework import mixins, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied, ValidationError

from apps.accounts.models import Role, User
from apps.accounts.permissions import IsParent, IsStaffRole

from .models import DeviceToken, EmergencyRequest, Notification, SupportMessage, SupportThread
from .serializers import (
    DeviceTokenSerializer,
    EmergencyRequestSerializer,
    NotificationSerializer,
    SupportMessageSerializer,
    SupportThreadSerializer,
)


class NotificationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=["post"])
    def read(self, request, pk=None):
        notif = self.get_object()
        notif.is_read = True
        notif.save(update_fields=["is_read"])
        return Response({"is_read": True})

    @action(detail=False, methods=["post"])
    def read_all(self, request):
        self.get_queryset().update(is_read=True)
        return Response({"status": "ok"})


class DeviceTokenViewSet(mixins.CreateModelMixin, viewsets.GenericViewSet):
    serializer_class = DeviceTokenSerializer
    queryset = DeviceToken.objects.all()


class EmergencyRequestViewSet(viewsets.ModelViewSet):
    serializer_class = EmergencyRequestSerializer

    def get_permissions(self):
        return super().get_permissions()

    def get_queryset(self):
        user = self.request.user
        qs = EmergencyRequest.objects.all()
        if user.role in (Role.OPERATOR, Role.ADMIN):
            return qs
        return qs.filter(created_by=user)

    @action(detail=True, methods=["post"], permission_classes=[IsStaffRole])
    def resolve(self, request, pk=None):
        req = self.get_object()
        req.status = EmergencyRequest.Status.RESOLVED
        req.handled_by = request.user
        req.save(update_fields=["status", "handled_by"])
        return Response(EmergencyRequestSerializer(req).data)


class SupportThreadViewSet(viewsets.ModelViewSet):
    serializer_class = SupportThreadSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = (
            SupportThread.objects.select_related("participant", "assigned_to", "trip")
            .prefetch_related("messages")
            .all()
        )
        if user.role in (Role.ADMIN, Role.OPERATOR):
            return qs
        if user.role == Role.ACCOUNTANT:
            return qs.filter(assigned_to=user)
        return qs.filter(participant=user)

    def perform_create(self, serializer):
        user = self.request.user
        participant = user
        if user.role in (Role.ADMIN, Role.OPERATOR):
            participant_id = self.request.data.get("participant")
            if not participant_id:
                raise ValidationError({"participant": "Укажите клиента или водителя."})
            try:
                participant = User.objects.get(pk=participant_id)
            except User.DoesNotExist as exc:
                raise ValidationError({"participant": "Пользователь не найден."}) from exc

        thread = serializer.save(
            participant=participant,
            assigned_to=user if user.role in (Role.ADMIN, Role.OPERATOR) else None,
            last_message_at=timezone.now(),
        )
        body = (self.request.data.get("message") or "").strip()
        if body:
            SupportMessage.objects.create(
                thread=thread,
                sender=user,
                sender_role=self._sender_role(user),
                body=body,
            )

    @action(detail=True, methods=["post"])
    def messages(self, request, pk=None):
        thread = self.get_object()
        user = request.user
        if user.role not in (Role.ADMIN, Role.OPERATOR) and thread.participant_id != user.id:
            raise PermissionDenied("Нет доступа к этому чату.")

        body = (request.data.get("body") or request.data.get("message") or "").strip()
        if not body:
            raise ValidationError({"body": "Введите сообщение."})

        if user.role in (Role.ADMIN, Role.OPERATOR) and not thread.assigned_to_id:
            thread.assigned_to = user
        if thread.status == SupportThread.Status.OPEN and user.role in (Role.ADMIN, Role.OPERATOR):
            thread.status = SupportThread.Status.IN_PROGRESS
        thread.last_message_at = timezone.now()
        thread.save(update_fields=["assigned_to", "status", "last_message_at", "updated_at"])

        message = SupportMessage.objects.create(
            thread=thread,
            sender=user,
            sender_role=self._sender_role(user),
            body=body,
        )
        return Response(SupportMessageSerializer(message).data, status=201)

    @action(detail=True, methods=["post"], permission_classes=[IsStaffRole])
    def resolve(self, request, pk=None):
        thread = self.get_object()
        thread.status = SupportThread.Status.RESOLVED
        thread.assigned_to = request.user
        thread.last_message_at = timezone.now()
        thread.save(update_fields=["status", "assigned_to", "last_message_at", "updated_at"])
        return Response(SupportThreadSerializer(thread).data)

    def _sender_role(self, user):
        if user.role in {Role.PARENT, Role.DRIVER, Role.OPERATOR, Role.ADMIN, Role.ACCOUNTANT}:
            return user.role
        return SupportMessage.SenderRole.SYSTEM


@api_view(["POST"])
@permission_classes([IsParent])
def support_ai_reply(request):
    message = (request.data.get("message") or "").strip()
    history = request.data.get("history") or []
    if not message:
        return Response({"reply": "Напишите вопрос, и я помогу с поездкой."})

    fallback = (
        "Я передам это оператору, если вопрос срочный. "
        "Пока могу помочь проверить статус поездки, оплату, маршрут или данные ребёнка."
    )
    if not settings.GROQ_API_KEY:
        return Response({"reply": fallback, "provider": "local"})

    messages = [
        {
            "role": "system",
            "content": (
                "Ты AI-помощник сервиса Детское такси. Отвечай кратко, "
                "спокойно и по делу на языке пользователя. Не обещай того, "
                "что требует оператора; предложи передать оператору при риске."
            ),
        }
    ]
    for item in history[-8:]:
        role = "assistant" if item.get("role") == "assistant" else "user"
        content = str(item.get("content") or "").strip()
        if content:
            messages.append({"role": role, "content": content[:800]})
    messages.append({"role": "user", "content": message[:1200]})

    try:
        resp = requests.post(
            settings.GROQ_CHAT_COMPLETIONS_URL,
            headers={
                "Authorization": f"Bearer {settings.GROQ_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.GROQ_MODEL,
                "messages": messages,
                "temperature": 0.3,
                "max_tokens": 280,
            },
            timeout=18,
        )
        resp.raise_for_status()
        data = resp.json()
        reply = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
            .strip()
        )
        return Response({"reply": reply or fallback, "provider": "groq"})
    except (requests.RequestException, ValueError, KeyError, IndexError):
        return Response({"reply": fallback, "provider": "local"})
