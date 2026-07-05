from django.contrib import admin

from .models import DriverProfile, SalaryScheme, Tariff, Vehicle


@admin.register(DriverProfile)
class DriverProfileAdmin(admin.ModelAdmin):
    list_display = ["full_name", "phone", "doc_status", "is_available", "rating"]
    list_filter = ["doc_status", "is_available"]
    search_fields = ["full_name", "phone", "iin"]


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = ["plate_number", "make", "model", "driver", "is_active"]
    search_fields = ["plate_number"]


admin.site.register(Tariff)
admin.site.register(SalaryScheme)
