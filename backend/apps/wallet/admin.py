from django.contrib import admin

from .models import Subscription, SubscriptionPlan, Wallet, WalletTransaction


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ["parent", "balance", "currency", "updated_at"]


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ["wallet", "kind", "amount", "balance_after", "created_at"]
    list_filter = ["kind"]


admin.site.register(SubscriptionPlan)
admin.site.register(Subscription)
