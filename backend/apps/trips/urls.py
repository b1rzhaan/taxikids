from rest_framework.routers import DefaultRouter

from .views import RecurringTripPlanViewSet, TripViewSet

router = DefaultRouter()
router.register("trips", TripViewSet, basename="trip")
router.register("plans", RecurringTripPlanViewSet, basename="plan")

urlpatterns = router.urls
