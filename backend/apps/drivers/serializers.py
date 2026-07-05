from rest_framework import serializers

from .models import DriverProfile, SalaryScheme, Tariff, Vehicle


class VehicleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = [
            "id", "driver", "make", "model", "plate_number",
            "color", "seats", "year", "mileage_km", "photo",
            "tech_passport", "is_active",
        ]


class SalarySchemeSerializer(serializers.ModelSerializer):
    class Meta:
        model = SalaryScheme
        fields = ["id", "name", "type", "value", "is_active"]


class TariffSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tariff
        fields = [
            "id", "name", "base_fare", "per_km",
            "per_min", "min_fare", "is_active",
        ]


class DriverProfileSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(source="user.email", read_only=True)
    vehicles = VehicleSerializer(many=True, read_only=True)

    class Meta:
        model = DriverProfile
        fields = [
            "id", "email", "full_name", "phone", "iin",
            "license_number", "license_expiry", "doc_status",
            "experience_years", "has_child_seat", "rating",
            "is_available", "salary_scheme", "hired_at", "vehicles",
            "photo", "license_photo", "id_card_photo",
        ]
        read_only_fields = ["id", "rating"]


class DriverPublicSerializer(serializers.ModelSerializer):
    """What a parent sees about their assigned driver."""

    vehicle = serializers.SerializerMethodField()

    class Meta:
        model = DriverProfile
        fields = [
            "id", "full_name", "phone", "rating",
            "experience_years", "has_child_seat", "vehicle",
        ]

    def get_vehicle(self, obj):
        vehicle = obj.vehicles.filter(is_active=True).first()
        return VehicleSerializer(vehicle).data if vehicle else None
