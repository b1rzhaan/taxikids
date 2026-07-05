from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    DriverViewSet,
    SalarySchemeViewSet,
    TariffViewSet,
    VehicleViewSet,
    driver_me,
    driver_set_online,
    drivers_locations,
)

router = DefaultRouter()
router.register("drivers", DriverViewSet, basename="driver")
router.register("vehicles", VehicleViewSet, basename="vehicle")
router.register("tariffs", TariffViewSet, basename="tariff")
router.register("salary-schemes", SalarySchemeViewSet, basename="salary-scheme")

# Explicit driver-self routes must precede the router's /drivers/{pk}/.
urlpatterns = [
    path("drivers/me/", driver_me, name="driver-me"),
    path("drivers/me/online/", driver_set_online, name="driver-online"),
    path("drivers/locations/", drivers_locations, name="drivers-locations"),
    *router.urls,
]
