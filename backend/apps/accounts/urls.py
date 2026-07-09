from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    DriverRegisterView,
    LoginView,
    MeView,
    ParentProfileViewSet,
    ParentRegisterView,
    SavedAddressViewSet,
)

router = DefaultRouter()
router.register("addresses", SavedAddressViewSet, basename="address")
router.register("parents", ParentProfileViewSet, basename="parent-profile")

urlpatterns = [
    path("login/", LoginView.as_view(), name="login"),
    path("register/", ParentRegisterView.as_view(), name="register"),
    path("register-driver/", DriverRegisterView.as_view(), name="register-driver"),
    path("refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("me/", MeView.as_view(), name="me"),
    path("", include(router.urls)),
]
