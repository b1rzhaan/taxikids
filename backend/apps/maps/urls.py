from django.urls import path

from .views import (
    EstimateView,
    GeocodeView,
    MapConfigView,
    ReverseGeocodeView,
    RouteView,
    SuggestView,
)

urlpatterns = [
    path("config/", MapConfigView.as_view(), name="map-config"),
    path("geocode/", GeocodeView.as_view(), name="geocode"),
    path("suggest/", SuggestView.as_view(), name="suggest"),
    path("reverse/", ReverseGeocodeView.as_view(), name="reverse-geocode"),
    path("route/", RouteView.as_view(), name="route"),
    path("estimate/", EstimateView.as_view(), name="estimate"),
]
