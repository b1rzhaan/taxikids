from django.db import transaction
from rest_framework import generics, permissions, status, viewsets
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import ParentProfile, Role, SavedAddress, User
from .serializers import (
    ParentRegisterSerializer,
    ParentProfileSerializer,
    RoleAwareTokenSerializer,
    SavedAddressSerializer,
    UserSerializer,
)
from .permissions import IsAdminOrOperator, IsStaffRole


def _int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _session_for(user) -> dict:
    """Issue a login-style token bundle (mirrors RoleAwareTokenSerializer)."""
    refresh = RefreshToken.for_user(user)
    refresh["role"] = user.role
    refresh["email"] = user.email
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "role": user.role,
        "user_id": user.id,
        "email": user.email,
    }


class LoginView(TokenObtainPairView):
    """POST /api/auth/login/ → {access, refresh, role, user_id, email}."""

    serializer_class = RoleAwareTokenSerializer


class ParentRegisterView(generics.CreateAPIView):
    """POST /api/auth/register/ — parent self-registration only."""

    queryset = User.objects.all()
    serializer_class = ParentRegisterSerializer
    permission_classes = [permissions.AllowAny]


class DriverRegisterView(APIView):
    """POST /api/auth/register-driver/ (multipart) — driver self-registration.

    Creates a PENDING driver + vehicle + document photos and logs the driver in
    right away. The account works but stays limited until an operator approves
    the documents (doc_status → approved)."""

    permission_classes = [permissions.AllowAny]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    @transaction.atomic
    def post(self, request):
        from apps.drivers.models import DriverProfile, Vehicle

        d = request.data
        email = (d.get("email") or "").strip().lower()
        password = d.get("password") or ""
        if not email or not password:
            return Response({"detail": "email и пароль обязательны"}, status=400)
        if len(password) < 6:
            return Response({"detail": "Пароль минимум 6 символов"}, status=400)
        if User.objects.filter(email=email).exists():
            return Response(
                {"detail": "Пользователь с таким email уже существует"},
                status=400,
            )
        plate = (d.get("car_plate") or "").strip().upper()
        if plate and Vehicle.objects.filter(plate_number=plate).exists():
            return Response(
                {"detail": "Автомобиль с таким госномером уже зарегистрирован"},
                status=400,
            )

        user = User.objects.create_user(
            email=email,
            password=password,
            role=Role.DRIVER,
            phone=(d.get("phone") or "").strip(),
        )
        driver = DriverProfile.objects.create(
            user=user,
            full_name=(d.get("full_name") or "").strip(),
            phone=(d.get("phone") or "").strip(),
            iin=(d.get("iin") or "").strip(),
            doc_status=DriverProfile.DocStatus.PENDING,
            is_available=False,
        )
        for field in ("photo", "license_photo", "id_card_photo"):
            f = request.FILES.get(field)
            if f:
                setattr(driver, field, f)
        driver.save()

        vehicle = Vehicle.objects.create(
            driver=driver,
            make=(d.get("car_make") or "").strip(),
            model=(d.get("car_model") or "").strip(),
            color=(d.get("car_color") or "").strip(),
            plate_number=plate or f"NEW-{user.id}",
            mileage_km=_int(d.get("car_mileage")),
        )
        car_photo = request.FILES.get("car_photo")
        if car_photo:
            vehicle.photo = car_photo
            vehicle.save(update_fields=["photo"])

        return Response(_session_for(user), status=status.HTTP_201_CREATED)


class MeView(generics.RetrieveAPIView):
    """GET/PATCH /api/auth/me/ — current user identity + profile update."""

    serializer_class = UserSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_object(self):
        return self.request.user

    def patch(self, request, *args, **kwargs):
        user = request.user
        profile = getattr(user, "parent_profile", None)
        if profile is None:
            profile = getattr(user, "driver_profile", None)
        if profile is None:
            return Response({"detail": "profile update is not available"}, status=400)

        full_name = (request.data.get("full_name") or "").strip()
        phone = (request.data.get("phone") or "").strip()
        if full_name:
            profile.full_name = full_name
        if hasattr(profile, "phone"):
            profile.phone = phone
        user.phone = phone
        photo = request.FILES.get("photo")
        if photo:
            profile.photo = photo
        profile.save()
        user.save(update_fields=["phone"])
        return Response(self.get_serializer(user).data)


class SavedAddressViewSet(viewsets.ModelViewSet):
    serializer_class = SavedAddressSerializer

    def get_queryset(self):
        # Most-recent first so it reads like a "recent addresses" list.
        return SavedAddress.objects.filter(owner=self.request.user).order_by(
            "-created_at"
        )


class ParentProfileViewSet(viewsets.ModelViewSet):
    queryset = ParentProfile.objects.select_related("user").prefetch_related(
        "children"
    )
    serializer_class = ParentProfileSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    search_fields = ["full_name", "phone", "user__email", "children__full_name"]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsStaffRole()]
        return [IsAdminOrOperator()]

    def perform_update(self, serializer):
        parent = serializer.save()
        if parent.phone:
            parent.user.phone = parent.phone
            parent.user.save(update_fields=["phone"])
