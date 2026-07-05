from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

api_v1 = [
    path("auth/", include("apps.accounts.urls")),
    path("children/", include("apps.children.urls")),
    path("", include("apps.drivers.urls")),
    path("", include("apps.trips.urls")),
    path("maps/", include("apps.maps.urls")),
    path("payments/", include("apps.payments.urls")),
    path("wallet/", include("apps.wallet.urls")),
    path("", include("apps.payouts.urls")),
    path("notifications/", include("apps.notifications.urls")),
    path("statistics/", include("apps.statistics.urls")),
]

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include(api_v1)),
    # OpenAPI / Swagger
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
