from rest_framework.routers import DefaultRouter

from .views import ChildViewSet

router = DefaultRouter()
router.register("", ChildViewSet, basename="child")

urlpatterns = router.urls
