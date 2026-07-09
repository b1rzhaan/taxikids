from rest_framework import serializers

from .models import (
    DeviceToken,
    EmergencyRequest,
    Notification,
    SupportMessage,
    SupportThread,
)


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "type", "title", "body", "data", "channel", "is_read", "created_at"]


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ["id", "token", "platform"]

    def create(self, validated_data):
        user = self.context["request"].user
        obj, _ = DeviceToken.objects.update_or_create(
            token=validated_data["token"],
            defaults={"user": user, "platform": validated_data["platform"]},
        )
        return obj


class EmergencyRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyRequest
        fields = ["id", "trip", "type", "message", "status", "created_at"]
        read_only_fields = ["id", "status", "created_at"]

    def create(self, validated_data):
        validated_data["created_by"] = self.context["request"].user
        return super().create(validated_data)


class SupportMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    sender_email = serializers.EmailField(source="sender.email", read_only=True)

    class Meta:
        model = SupportMessage
        fields = [
            "id",
            "thread",
            "sender",
            "sender_name",
            "sender_email",
            "sender_role",
            "body",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "thread",
            "sender",
            "sender_name",
            "sender_email",
            "sender_role",
            "created_at",
        ]

    def get_sender_name(self, obj):
        if not obj.sender:
            return obj.get_sender_role_display()
        if hasattr(obj.sender, "parent_profile"):
            return obj.sender.parent_profile.full_name
        if hasattr(obj.sender, "driver_profile"):
            return obj.sender.driver_profile.full_name
        return obj.sender.email


class SupportThreadSerializer(serializers.ModelSerializer):
    participant_name = serializers.SerializerMethodField()
    participant_email = serializers.EmailField(source="participant.email", read_only=True)
    assigned_to_email = serializers.EmailField(source="assigned_to.email", read_only=True)
    messages = SupportMessageSerializer(many=True, read_only=True)
    last_message = serializers.SerializerMethodField()
    trip_id = serializers.IntegerField(source="trip.id", read_only=True)

    class Meta:
        model = SupportThread
        fields = [
            "id",
            "participant",
            "participant_name",
            "participant_email",
            "trip",
            "trip_id",
            "assigned_to",
            "assigned_to_email",
            "subject",
            "status",
            "last_message",
            "last_message_at",
            "created_at",
            "updated_at",
            "messages",
        ]
        read_only_fields = [
            "id",
            "participant",
            "participant_name",
            "participant_email",
            "assigned_to",
            "assigned_to_email",
            "last_message",
            "last_message_at",
            "created_at",
            "updated_at",
            "messages",
        ]

    def get_participant_name(self, obj):
        user = obj.participant
        if hasattr(user, "parent_profile"):
            return user.parent_profile.full_name
        if hasattr(user, "driver_profile"):
            return user.driver_profile.full_name
        return user.email

    def get_last_message(self, obj):
        msg = obj.messages.order_by("-created_at").first()
        if not msg:
            return ""
        return msg.body
