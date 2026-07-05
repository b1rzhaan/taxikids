from rest_framework import serializers

from .models import DriverEarning, Payout


class DriverEarningSerializer(serializers.ModelSerializer):
    driver_name = serializers.CharField(source="driver.full_name", read_only=True)

    class Meta:
        model = DriverEarning
        fields = ["id", "driver", "driver_name", "trip", "amount", "status", "created_at"]


class PayoutSerializer(serializers.ModelSerializer):
    driver_name = serializers.CharField(source="driver.full_name", read_only=True)
    items_count = serializers.IntegerField(source="items.count", read_only=True)

    class Meta:
        model = Payout
        fields = [
            "id", "driver", "driver_name", "period_start", "period_end",
            "total_amount", "status", "items_count", "paid_at", "created_at",
        ]


class CreatePayoutSerializer(serializers.Serializer):
    driver_id = serializers.IntegerField()
    period_start = serializers.DateField()
    period_end = serializers.DateField()
