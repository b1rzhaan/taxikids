from django.urls import path

from .views import (
    MySubscriptionsView,
    SubscriptionPlanListView,
    WalletTransactionsView,
    buy_subscription_view,
    topup_checkout,
    topup_create,
    topup_halyk_page,
    wallet_balance,
)

urlpatterns = [
    path("", wallet_balance, name="wallet-balance"),
    path("topup/create/", topup_create, name="wallet-topup-create"),
    path("topup/checkout/", topup_checkout, name="wallet-topup-checkout"),
    path("topup/halyk/page/<str:ref>/", topup_halyk_page, name="wallet-topup-halyk-page"),
    path("transactions/", WalletTransactionsView.as_view(), name="wallet-transactions"),
    path("plans/", SubscriptionPlanListView.as_view(), name="subscription-plans"),
    path("subscriptions/", MySubscriptionsView.as_view(), name="my-subscriptions"),
    path("subscriptions/buy/", buy_subscription_view, name="buy-subscription"),
]
