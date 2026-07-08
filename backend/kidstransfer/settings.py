"""
Django settings for the KidsTransfer backend.

Configuration is driven by environment variables (see .env.example) so the same
codebase runs identically in Docker, CI, and local dev.
"""
import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env from the repo root (one level above backend/) when present.
load_dotenv(BASE_DIR.parent / ".env")
load_dotenv(BASE_DIR / ".env")


def env_bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(int(default))).lower() in ("1", "true", "yes", "on")


def env_list(name: str, default: str = "") -> list[str]:
    return [x.strip() for x in os.getenv(name, default).split(",") if x.strip()]


# ── Core ──────────────────────────────────────────────────────────────
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "insecure-dev-key")
DEBUG = env_bool("DJANGO_DEBUG", True)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")
if DEBUG:
    # Dev conveniences: Android emulator host (10.0.2.2), LAN binding, test client.
    for _h in ("10.0.2.2", "0.0.0.0", "testserver"):
        if _h not in ALLOWED_HOSTS:
            ALLOWED_HOSTS.append(_h)

# Render injects the public hostname at runtime — trust it automatically.
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS")
_RENDER_HOST = os.getenv("RENDER_EXTERNAL_HOSTNAME")
if _RENDER_HOST:
    ALLOWED_HOSTS.append(_RENDER_HOST)
    CSRF_TRUSTED_ORIGINS.append(f"https://{_RENDER_HOST}")

# ── Applications ──────────────────────────────────────────────────────
DJANGO_APPS = [
    # daphne must precede staticfiles so `runserver` becomes ASGI-capable
    # (serves both HTTP and WebSocket for live tracking).
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

THIRD_PARTY_APPS = [
    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    "django_filters",
    "drf_spectacular",
    "channels",
]

LOCAL_APPS = [
    "apps.accounts",
    "apps.children",
    "apps.drivers",
    "apps.trips",
    "apps.maps",
    "apps.payments",
    "apps.wallet",
    "apps.payouts",
    "apps.notifications",
    "apps.statistics",
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",  # serves static in prod
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "kidstransfer.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "kidstransfer.wsgi.application"
ASGI_APPLICATION = "kidstransfer.asgi.application"

# ── Database ──────────────────────────────────────────────────────────
# Postgres in Docker/prod; set USE_SQLITE=1 for a zero-dependency local run.
if env_bool("USE_SQLITE", False):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.getenv("POSTGRES_DB", "kidstransfer"),
            "USER": os.getenv("POSTGRES_USER", "kidstransfer"),
            "PASSWORD": os.getenv("POSTGRES_PASSWORD", "kidstransfer"),
            "HOST": os.getenv("POSTGRES_HOST", "localhost"),
            "PORT": os.getenv("POSTGRES_PORT", "5432"),
        }
    }

# Render (and most PaaS) provide a single DATABASE_URL — it wins when set.
if os.getenv("DATABASE_URL"):
    import dj_database_url

    DATABASES["default"] = dj_database_url.parse(
        os.environ["DATABASE_URL"], conn_max_age=600, ssl_require=not DEBUG
    )

# ── Channels (live tracking) ──────────────────────────────────────────
# Redis is optional: without REDIS_URL we fall back to an in-process layer,
# which is enough for a single web instance (fine for the first deploy).
REDIS_URL = os.getenv("REDIS_URL", "")
if REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {"hosts": [REDIS_URL]},
        }
    }
else:
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }

# ── Celery (scheduled trips, notifications) ───────────────────────────
CELERY_BROKER_URL = REDIS_URL or "memory://"
CELERY_RESULT_BACKEND = REDIS_URL or "cache+memory://"
# Without a broker, run tasks synchronously so nothing silently stalls.
CELERY_TASK_ALWAYS_EAGER = env_bool("CELERY_EAGER", not bool(REDIS_URL))

# ── Auth ──────────────────────────────────────────────────────────────
AUTH_USER_MODEL = "accounts.User"
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

# ── DRF ───────────────────────────────────────────────────────────────
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.OrderingFilter",
        "rest_framework.filters.SearchFilter",
    ),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_PAGINATION_CLASS": "kidstransfer.pagination.DefaultPagination",
    "PAGE_SIZE": 20,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(os.getenv("JWT_ACCESS_LIFETIME_MIN", "60"))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(os.getenv("JWT_REFRESH_LIFETIME_DAYS", "7"))),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
}

SPECTACULAR_SETTINGS = {
    "TITLE": "KidsTransfer API",
    "DESCRIPTION": "Backend API for the KidsTransfer child transportation service.",
    "VERSION": "0.1.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# ── CORS (web cabinet + mobile) ───────────────────────────────────────
# Native apps send no Origin; the API is JWT-protected — allow-all is safe here.
CORS_ALLOW_ALL_ORIGINS = DEBUG or env_bool("CORS_ALLOW_ALL", True)
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS", "http://localhost:3000")

# ── i18n / static ─────────────────────────────────────────────────────
LANGUAGE_CODE = "ru"
TIME_ZONE = "Asia/Almaty"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

# Static via WhiteNoise; media stays local in dev, goes to Cloudinary in prod
# (Render's disk is ephemeral, so uploaded photos need external storage).
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedStaticFilesStorage"
    },
}
if os.getenv("CLOUDINARY_URL"):
    INSTALLED_APPS += ["cloudinary", "cloudinary_storage"]
    STORAGES["default"] = {
        "BACKEND": "cloudinary_storage.storage.MediaCloudinaryStorage"
    }

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ── Pluggable providers (Ports & Adapters) ────────────────────────────
MAP_PROVIDER = os.getenv("MAP_PROVIDER", "mock")
# Bias geocoding/suggestions toward the service city (Almaty by default) so a
# query like "Достык 91" ranks local results first instead of other cities.
MAP_BIAS_LAT = float(os.getenv("MAP_BIAS_LAT", "43.238"))
MAP_BIAS_LNG = float(os.getenv("MAP_BIAS_LNG", "76.945"))
TWOGIS_API_KEY = os.getenv("TWOGIS_API_KEY", "")
TWOGIS_BASE_URL = os.getenv("TWOGIS_BASE_URL", "https://routing.api.2gis.com")
TWOGIS_CATALOG_URL = os.getenv("TWOGIS_CATALOG_URL", "https://catalog.api.2gis.com")

PAYMENT_PROVIDER = os.getenv("PAYMENT_PROVIDER", "mock")  # mock | halyk | stripe
PAYMENT_WEBHOOK_SECRET = os.getenv("PAYMENT_WEBHOOK_SECRET", "mock-webhook-secret")

# ── Halyk Bank ePay (Kazakhstan acquiring) ────────────────────────────
# Defaults are Halyk's PUBLIC sandbox credentials — swap for real merchant
# keys (client_id/secret/terminal from the bank) to go live.
HALYK_OAUTH_URL = os.getenv(
    "HALYK_OAUTH_URL", "https://testoauth.homebank.kz/epay2/oauth2/token")
HALYK_API_URL = os.getenv("HALYK_API_URL", "https://testepay.homebank.kz/api")
# The widget JS is served only from the prod CDN (epay.homebank.kz); the test
# host does not serve it. Environment (test/prod) is chosen by the auth token.
HALYK_WIDGET_JS = os.getenv(
    "HALYK_WIDGET_JS", "https://epay.homebank.kz/payform/payment-api.js")
HALYK_CLIENT_ID = os.getenv("HALYK_CLIENT_ID", "test")
HALYK_CLIENT_SECRET = os.getenv(
    "HALYK_CLIENT_SECRET", "yF587AV9Ms94qN2QShFzVR3vFnWkhjbAK3sG")
HALYK_TERMINAL = os.getenv(
    "HALYK_TERMINAL", "67e34d63-102f-4bd1-898e-370781d0074d")
# Marker URLs the mobile WebView watches to detect success / failure.
HALYK_BACK_LINK = os.getenv("HALYK_BACK_LINK", "https://kidstransfer.success/")
HALYK_FAILURE_LINK = os.getenv("HALYK_FAILURE_LINK", "https://kidstransfer.fail/")

# Stripe Checkout (test/demo mode). Stripe is not currently a direct acquiring
# option for Kazakhstan-based merchants, but it is useful for demo card flows
# while the local bank/ioka/Kaspi contract is being prepared.
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")
STRIPE_CURRENCY = os.getenv("STRIPE_CURRENCY", "usd").lower()
STRIPE_DEMO_KZT_TO_TARGET_RATE = os.getenv("STRIPE_DEMO_KZT_TO_TARGET_RATE", "500")
STRIPE_SUCCESS_URL = os.getenv(
    "STRIPE_SUCCESS_URL",
    "https://kidstransfer.success/stripe?session_id={CHECKOUT_SESSION_ID}",
)
STRIPE_CANCEL_URL = os.getenv(
    "STRIPE_CANCEL_URL",
    "https://kidstransfer.fail/stripe",
)

# ── Business rules ────────────────────────────────────────────────────
DRIVER_REVENUE_SHARE = float(os.getenv("DRIVER_REVENUE_SHARE", "0.70"))
DEFAULT_CURRENCY = os.getenv("DEFAULT_CURRENCY", "KZT")
