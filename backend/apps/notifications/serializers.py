from rest_framework import serializers

from .models import DeviceToken, EmergencyRequest, Notification


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
