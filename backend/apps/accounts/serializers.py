from django.db import transaction
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import ParentProfile, Role, SavedAddress, User


class RoleAwareTokenSerializer(TokenObtainPairSerializer):
    """Adds role + basic identity into the JWT payload and login response."""

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        token["email"] = user.email
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["role"] = self.user.role
        data["user_id"] = self.user.id
        data["email"] = self.user.email
        return data


class ParentRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    full_name = serializers.CharField(write_only=True, max_length=120)

    class Meta:
        model = User
        fields = ["id", "email", "phone", "password", "full_name"]

    @transaction.atomic
    def create(self, validated_data):
        full_name = validated_data.pop("full_name")
        password = validated_data.pop("password")
        user = User.objects.create_user(
            role=Role.PARENT, password=password, **validated_data
        )
        ParentProfile.objects.create(
            user=user, full_name=full_name, phone=user.phone
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "email", "phone", "role", "full_name", "date_joined"]

    def get_full_name(self, obj) -> str:
        if hasattr(obj, "parent_profile"):
            return obj.parent_profile.full_name
        if hasattr(obj, "driver_profile"):
            return obj.driver_profile.full_name
        return ""


class SavedAddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = SavedAddress
        fields = ["id", "label", "text", "lat", "lng", "created_at"]
        read_only_fields = ["id", "created_at"]

    def create(self, validated_data):
        user = self.context["request"].user
        # Dedup recent addresses by text so the list stays clean.
        obj, _ = SavedAddress.objects.update_or_create(
            owner=user,
            text=validated_data["text"],
            defaults={
                "label": validated_data.get("label", validated_data["text"]),
                "lat": validated_data["lat"],
                "lng": validated_data["lng"],
            },
        )
        return obj
