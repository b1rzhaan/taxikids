from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.accounts.permissions import IsParent

from .models import Subscription, SubscriptionPlan, WalletTransaction
from .serializers import (
    BuySubscriptionSerializer,
    SubscriptionPlanSerializer,
    SubscriptionSerializer,
    TopUpSerializer,
    WalletSerializer,
    WalletTransactionSerializer,
)
from .services import (
    buy_subscription,
    confirm_topup,
    create_topup,
    get_or_create_wallet,
)


@api_view(["GET"])
@permission_classes([IsParent])
def wallet_balance(request):
    wallet = get_or_create_wallet(request.user.parent_profile)
    return Response(WalletSerializer(wallet).data)


@api_view(["POST"])
@permission_classes([IsParent])
def topup_create(request):
    """Start a bank top-up: returns ref + provider + Halyk widget object/page."""
    ser = TopUpSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    intent, redirect_url = create_topup(
        request.user.parent_profile, ser.validated_data["amount"]
    )
    return Response({
        "ref": intent.ref,
        "amount": intent.amount,
        "provider": intent.provider,
        "redirect_url": redirect_url,
        "payment_object": intent.raw_payload or None,
    })


@api_view(["GET"])
@permission_classes([AllowAny])
def topup_halyk_page(request, ref):
    """Server-rendered Halyk widget page for a wallet top-up (fresh token)."""
    from django.http import HttpResponse

    from apps.payments.views import build_halyk_page

    from .models import TopUpIntent

    intent = get_object_or_404(TopUpIntent, ref=ref)
    html = build_halyk_page(
        intent.raw_payload or {},
        fallback_invoice=intent.ref,
        fallback_amount=intent.amount,
    )
    return HttpResponse(html, content_type="text/html; charset=utf-8")


@api_view(["GET", "POST"])
@permission_classes([IsParent])
def topup_checkout(request):
    """Mock bank checkout callback. POST ?ref=..&status=success|failed."""
    ref = request.query_params.get("ref") or request.data.get("ref")
    status_ = request.query_params.get("status") or request.data.get("status", "success")
    intent = confirm_topup(ref, status_ == "success")
    if intent is None:
        return Response({"detail": "unknown top-up"}, status=404)
    return Response({"status": intent.status})


class WalletTransactionsView(ListAPIView):
    serializer_class = WalletTransactionSerializer
    permission_classes = [IsParent]

    def get_queryset(self):
        return WalletTransaction.objects.filter(
            wallet__parent__user=self.request.user
        )


class SubscriptionPlanListView(ListAPIView):
    serializer_class = SubscriptionPlanSerializer
    queryset = SubscriptionPlan.objects.filter(is_active=True)
    permission_classes = [IsParent]


class MySubscriptionsView(ListAPIView):
    serializer_class = SubscriptionSerializer
    permission_classes = [IsParent]

    def get_queryset(self):
        return Subscription.objects.filter(parent__user=self.request.user)


@api_view(["POST"])
@permission_classes([IsParent])
def buy_subscription_view(request):
    ser = BuySubscriptionSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    plan = get_object_or_404(
        SubscriptionPlan, pk=ser.validated_data["plan_id"], is_active=True
    )
    try:
        sub = buy_subscription(request.user.parent_profile, plan)
    except ValueError as exc:
        raise ValidationError({"detail": str(exc)})
    return Response(SubscriptionSerializer(sub).data)
