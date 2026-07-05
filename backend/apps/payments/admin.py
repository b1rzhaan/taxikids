from django.contrib import admin

from .models import Payment


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ["id", "trip", "amount", "currency", "status", "provider", "created_at"]
    list_filter = ["status", "provider"]
    search_fields = ["provider_ref", "idempotency_key"]
