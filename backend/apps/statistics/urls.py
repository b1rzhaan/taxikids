from django.urls import path

from .views import dashboard, drivers_stats, revenue

urlpatterns = [
    path("dashboard/", dashboard, name="stats-dashboard"),
    path("revenue/", revenue, name="stats-revenue"),
    path("drivers/", drivers_stats, name="stats-drivers"),
]
