from rest_framework import serializers

from .models import Payment


class PaymentSerializer(serializers.ModelSerializer):
    child_name = serializers.CharField(source="trip.child.full_name", read_only=True)

    class Meta:
        model = Payment
        fields = [
            "id", "trip", "child_name", "provider", "provider_ref",
            "amount", "currency", "status", "created_at", "paid_at",
        ]


class CreatePaymentSerializer(serializers.Serializer):
    trip_id = serializers.IntegerField()
