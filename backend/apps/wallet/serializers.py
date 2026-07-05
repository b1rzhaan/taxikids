from decimal import Decimal

from rest_framework import serializers

from .models import Subscription, SubscriptionPlan, Wallet, WalletTransaction


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = ["id", "kind", "amount", "balance_after", "trip", "note", "created_at"]


class WalletSerializer(serializers.ModelSerializer):
    class Meta:
        model = Wallet
        fields = ["balance", "currency", "updated_at"]


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    price_per_trip = serializers.DecimalField(
        max_digits=10, decimal_places=2, read_only=True
    )

    class Meta:
        model = SubscriptionPlan
        fields = ["id", "name", "trips_count", "price", "price_per_trip",
                  "duration_days", "is_active"]


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = SubscriptionPlanSerializer(read_only=True)
    trips_remaining = serializers.IntegerField(read_only=True)

    class Meta:
        model = Subscription
        fields = ["id", "plan", "trips_total", "trips_used", "trips_remaining",
                  "valid_until", "status", "auto_renew", "created_at"]


class TopUpSerializer(serializers.Serializer):
    amount = serializers.DecimalField(
        max_digits=12, decimal_places=2, min_value=Decimal("1")
    )


class BuySubscriptionSerializer(serializers.Serializer):
    plan_id = serializers.IntegerField()
