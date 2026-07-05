from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.accounts.models import Role
from apps.accounts.permissions import IsStaffRole

from .models import DeviceToken, EmergencyRequest, Notification
from .serializers import (
    DeviceTokenSerializer,
    EmergencyRequestSerializer,
    NotificationSerializer,
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
