from django.contrib import admin

from .models import DriverEarning, Payout, PayoutItem


@admin.register(DriverEarning)
class DriverEarningAdmin(admin.ModelAdmin):
    list_display = ["driver", "trip", "amount", "status", "created_at"]
    list_filter = ["status"]


class PayoutItemInline(admin.TabularInline):
    model = PayoutItem
    extra = 0


@admin.register(Payout)
class PayoutAdmin(admin.ModelAdmin):
    list_display = ["driver", "period_start", "period_end", "total_amount", "status"]
    list_filter = ["status"]
    inlines = [PayoutItemInline]
