from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import EarningViewSet, PayoutViewSet, request_payout

router = DefaultRouter()
router.register("earnings", EarningViewSet, basename="earning")
router.register("payouts", PayoutViewSet, basename="payout")

urlpatterns = [
    path("payouts/request/", request_payout, name="payout-request"),
    *router.urls,
]
