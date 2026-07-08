from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    CreatePaymentView,
    HalykConfirmView,
    HalykPageView,
    PaymentViewSet,
    PaymentWebhookView,
    StripeConfirmView,
    mock_checkout,
)

router = DefaultRouter()
router.register("", PaymentViewSet, basename="payment")

urlpatterns = [
    path("create/", CreatePaymentView.as_view(), name="payment-create"),
    path("halyk/page/<int:payment_id>/", HalykPageView.as_view(), name="halyk-page"),
    path("halyk/confirm/", HalykConfirmView.as_view(), name="halyk-confirm"),
    path("stripe/confirm/", StripeConfirmView.as_view(), name="stripe-confirm"),
    path("webhook/<str:provider>/", PaymentWebhookView.as_view(), name="payment-webhook"),
    path("mock-checkout/", mock_checkout, name="mock-checkout"),
    path("", include(router.urls)),
]
