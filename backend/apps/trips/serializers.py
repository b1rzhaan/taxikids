from rest_framework import serializers

from apps.children.serializers import ChildSerializer
from apps.drivers.serializers import DriverPublicSerializer

from .models import RecurringTripPlan, Trip, TripLocation, TripStatusHistory
from .services import build_route_for_trip


class TripStatusHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = TripStatusHistory
        fields = ["id", "from_status", "to_status", "event", "note", "created_at"]


class TripLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = TripLocation
        fields = ["lat", "lng", "speed", "heading", "recorded_at"]


class TripListSerializer(serializers.ModelSerializer):
    child = ChildSerializer(read_only=True)
    child_name = serializers.CharField(source="child.full_name", read_only=True)
    driver_name = serializers.CharField(source="driver.full_name", read_only=True)
    parent_rating = serializers.SerializerMethodField()
    rating_comment = serializers.SerializerMethodField()

    class Meta:
        model = Trip
        fields = [
            "id", "child", "child_name", "driver_name",
            "pickup_text", "dropoff_text",
            "pickup_lat", "pickup_lng", "dropoff_lat", "dropoff_lng",
            "scheduled_at", "status", "payment_status", "payment_method",
            "price_amount", "price_currency",
            "route_distance_m", "route_duration_s",
            "parent_rating", "rating_comment",
        ]

    def _parent_rating(self, obj):
        # Uses the prefetched ratings list — no extra query per row.
        for r in obj.ratings.all():
            if r.role == "parent":
                return r
        return None

    def get_parent_rating(self, obj):
        r = self._parent_rating(obj)
        return r.stars if r else None

    def get_rating_comment(self, obj):
        r = self._parent_rating(obj)
        return r.comment if r else ""


class TripDetailSerializer(serializers.ModelSerializer):
    child = ChildSerializer(read_only=True)
    driver = DriverPublicSerializer(read_only=True)
    status_history = TripStatusHistorySerializer(many=True, read_only=True)
    last_location = serializers.SerializerMethodField()
    my_rating = serializers.SerializerMethodField()

    class Meta:
        model = Trip
        fields = [
            "id", "child", "driver", "vehicle",
            "pickup_text", "pickup_lat", "pickup_lng",
            "dropoff_text", "dropoff_lat", "dropoff_lng",
            "scheduled_at", "status", "payment_status", "payment_method",
            "price_amount", "price_currency",
            "route_distance_m", "route_duration_s", "route_polyline",
            "driver_earning_amount", "status_history", "last_location",
            "my_rating", "created_at",
        ]

    def get_last_location(self, obj):
        loc = obj.locations.first()
        return TripLocationSerializer(loc).data if loc else None

    def get_my_rating(self, obj):
        request = self.context.get("request")
        role = getattr(getattr(request, "user", None), "role", None)
        if not role:
            return None
        r = obj.ratings.filter(role=role).first()
        return r.stars if r else None


class TripCreateSerializer(serializers.ModelSerializer):
    """Parent creates a one-off order; route + price computed server-side."""

    class Meta:
        model = Trip
        fields = [
            "id", "child",
            "pickup_text", "pickup_lat", "pickup_lng",
            "dropoff_text", "dropoff_lat", "dropoff_lng",
            "scheduled_at", "tariff",
        ]

    def validate_child(self, child):
        request = self.context["request"]
        if child.parent.user_id != request.user.id:
            raise serializers.ValidationError("Это не ваш ребёнок.")
        return child

    def create(self, validated_data):
        from apps.drivers.models import Tariff

        request = self.context["request"]
        validated_data["parent"] = request.user.parent_profile
        if not validated_data.get("tariff"):
            validated_data["tariff"] = Tariff.objects.filter(is_active=True).first()
        trip = Trip(**validated_data)
        build_route_for_trip(trip)
        trip.save()
        return trip


class TripStatusEventSerializer(serializers.Serializer):
    event = serializers.CharField()
    note = serializers.CharField(required=False, allow_blank=True, default="")


class TripAssignSerializer(serializers.Serializer):
    driver_id = serializers.IntegerField()
    vehicle_id = serializers.IntegerField(required=False)


class DriverLocationSerializer(serializers.Serializer):
    lat = serializers.FloatField()
    lng = serializers.FloatField()
    speed = serializers.FloatField(required=False)
    heading = serializers.FloatField(required=False)


class RecurringTripPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecurringTripPlan
        fields = [
            "id", "child",
            "pickup_text", "pickup_lat", "pickup_lng",
            "dropoff_text", "dropoff_lat", "dropoff_lng",
            "weekdays", "pickup_time", "tariff",
            "is_active", "valid_from", "valid_to", "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_child(self, child):
        request = self.context["request"]
        if child.parent.user_id != request.user.id:
            raise serializers.ValidationError("Это не ваш ребёнок.")
        return child

    def create(self, validated_data):
        validated_data["parent"] = self.context["request"].user.parent_profile
        return super().create(validated_data)
