from django.contrib import admin

from .models import RecurringTripPlan, Trip, TripLocation, TripStatusHistory


class StatusHistoryInline(admin.TabularInline):
    model = TripStatusHistory
    extra = 0
    readonly_fields = ["from_status", "to_status", "event", "actor", "created_at"]


@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = [
        "id", "child", "driver", "status", "payment_status",
        "price_amount", "scheduled_at",
    ]
    list_filter = ["status", "payment_status"]
    search_fields = ["pickup_text", "dropoff_text"]
    inlines = [StatusHistoryInline]


admin.site.register(RecurringTripPlan)
admin.site.register(TripLocation)
