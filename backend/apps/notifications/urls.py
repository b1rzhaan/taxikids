from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    DeviceTokenViewSet,
    EmergencyRequestViewSet,
    NotificationViewSet,
    support_ai_reply,
)

# emergency + devices live under /api/notifications/… via their own router.
sub_router = DefaultRouter()
sub_router.register("emergency", EmergencyRequestViewSet, basename="emergency")
sub_router.register("devices", DeviceTokenViewSet, basename="device")

urlpatterns = [
    # Explicit notification routes so the list isn't shadowed by a router root.
    path("", NotificationViewSet.as_view({"get": "list"}), name="notification-list"),
    path(
        "read_all/",
        NotificationViewSet.as_view({"post": "read_all"}),
        name="notification-read-all",
    ),
    path(
        "<int:pk>/read/",
        NotificationViewSet.as_view({"post": "read"}),
        name="notification-read",
    ),
    path("support/ai/", support_ai_reply, name="support-ai"),
    path("", include(sub_router.urls)),
]
