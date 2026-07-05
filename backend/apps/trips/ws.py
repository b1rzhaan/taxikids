"""WebSocket live-tracking: parents/operators subscribe to a trip channel;
the driver's location POSTs are broadcast to that group in real time."""
from __future__ import annotations

import json
from urllib.parse import parse_qs

from asgiref.sync import async_to_sync
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.layers import get_channel_layer
from django.urls import path


def _group(trip_id) -> str:
    return f"trip_{trip_id}"


def broadcast_location(trip_id, location: dict) -> None:
    """Called from the REST location endpoint to push to WS subscribers."""
    layer = get_channel_layer()
    if layer is None:
        return
    async_to_sync(layer.group_send)(
        _group(trip_id), {"type": "trip.location", "location": location}
    )


class TripTrackConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get("user")
        self.trip_id = self.scope["url_route"]["kwargs"]["trip_id"]
        if self.user is None:
            await self.close(code=4001)
            return
        allowed = await self._can_view(self.user, self.trip_id)
        if not allowed:
            await self.close(code=4003)
            return
        await self.channel_layer.group_add(_group(self.trip_id), self.channel_name)
        await self.accept()

    async def disconnect(self, code):
        await self.channel_layer.group_discard(_group(self.trip_id), self.channel_name)

    async def trip_location(self, event):
        await self.send(text_data=json.dumps({
            "type": "location",
            "trip_id": self.trip_id,
            "location": event["location"],
        }))

    @database_sync_to_async
    def _can_view(self, user, trip_id) -> bool:
        from apps.accounts.models import Role

        from .models import Trip

        trip = Trip.objects.filter(pk=trip_id).select_related(
            "parent", "driver"
        ).first()
        if not trip:
            return False
        if user.role in (Role.OPERATOR, Role.ADMIN):
            return True
        if user.role == Role.PARENT:
            return trip.parent.user_id == user.id
        if user.role == Role.DRIVER:
            return trip.driver and trip.driver.user_id == user.id
        return False


class JWTAuthMiddleware:
    """Authenticate WebSocket connections via ?token=<access_jwt>."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        scope["user"] = await self._get_user(scope)
        return await self.app(scope, receive, send)

    @database_sync_to_async
    def _get_user(self, scope):
        from rest_framework_simplejwt.exceptions import TokenError
        from rest_framework_simplejwt.tokens import AccessToken

        from apps.accounts.models import User

        qs = parse_qs(scope.get("query_string", b"").decode())
        token = (qs.get("token") or [None])[0]
        if not token:
            return None
        try:
            data = AccessToken(token)
            return User.objects.filter(pk=data["user_id"]).first()
        except (TokenError, KeyError):
            return None


websocket_urlpatterns = [
    path("ws/trips/<int:trip_id>/", TripTrackConsumer.as_asgi()),
]
