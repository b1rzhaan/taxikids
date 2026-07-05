from django.shortcuts import get_object_or_404
from rest_framework import mixins, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import Role
from apps.accounts.permissions import IsFinanceRole, IsParent
from apps.trips.models import Trip

from .models import Payment
from .serializers import CreatePaymentSerializer, PaymentSerializer
from .services import confirm_payment, create_payment_for_trip, get_payment_provider


class CreatePaymentView(APIView):
    """POST /api/payments/create/ {trip_id} → {payment_id, redirect_url}."""

    permission_classes = [IsParent]

    def post(self, request):
        ser = CreatePaymentSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        trip = get_object_or_404(Trip, pk=ser.validated_data["trip_id"])
        if trip.parent.user_id != request.user.id:
            raise PermissionDenied("Not your trip")
        try:
            payment, redirect_url = create_payment_for_trip(trip)
        except ValueError as exc:
            raise ValidationError({"detail": str(exc)})
        return Response({
            "payment_id": payment.id,
            "provider": payment.provider,
            "provider_ref": payment.provider_ref,
            "amount": payment.amount,
            "redirect_url": redirect_url,
            # Halyk ePay widget object (empty for mock provider).
            "payment_object": payment.raw_payload or None,
        })


def _halyk_page_html(widget_js: str, payment_object: dict) -> str:
    import json

    po = json.dumps(payment_object)
    return f"""<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{{margin:0;height:100%;font-family:sans-serif;background:#fff}}
#msg{{padding:24px;color:#666;text-align:center;line-height:1.5}}</style>
<script src="{widget_js}"
  onerror="document.getElementById('msg').innerText='Не удалось загрузить виджет банка (нет связи с epay.homebank.kz)'"></script>
</head>
<body>
<div id="msg">Открываем безопасную оплату Halyk…</div>
<script>
  var po = {po};
  var launched = false;
  function launch() {{
    try {{
      if (window.halyk && typeof halyk.pay === 'function') {{ launched = true; halyk.pay(po); }}
      else if (window.halyk && typeof halyk.showPaymentWidget === 'function') {{ launched = true; halyk.showPaymentWidget(po, function(r){{}}); }}
    }} catch(e) {{ document.getElementById('msg').innerText = 'Ошибка запуска оплаты: ' + e; }}
  }}
  if (window.halyk) launch(); else window.addEventListener('load', launch);
  // Diagnostics: if the widget never launched, tell the user instead of a blank screen.
  setTimeout(function() {{
    if (!launched && !window.halyk) {{
      document.getElementById('msg').innerText =
        'Виджет Halyk не загрузился. Проверьте интернет на устройстве и доступ к epay.homebank.kz.';
    }}
  }}, 8000);
</script>
</body></html>"""


class HalykPageView(APIView):
    """Server-rendered Halyk widget page (loaded by the mobile WebView).

    Serving from a real origin (not about:blank) is what makes the bank's
    payment-api.js widget initialise correctly."""

    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, payment_id):
        from django.http import HttpResponse

        payment = get_object_or_404(Payment, pk=payment_id)
        html = build_halyk_page(
            payment.raw_payload or {},
            fallback_invoice=payment.provider_ref,
            fallback_amount=payment.amount,
        )
        return HttpResponse(html, content_type="text/html; charset=utf-8")


def build_halyk_page(meta: dict, fallback_invoice: str, fallback_amount) -> str:
    """Build the Halyk widget page with a FRESH token (generated now)."""
    from .services import get_payment_provider

    prov = get_payment_provider()
    if not hasattr(prov, "build_widget"):
        return _halyk_page_html("", {})
    try:
        obj = prov.build_widget(
            meta.get("invoiceId", fallback_invoice),
            meta.get("amount", int(round(float(fallback_amount)))),
            meta.get("currency", "KZT"),
            meta.get("description", "Оплата"),
            meta.get("accountId", "parent"),
        )
        return _halyk_page_html(obj["widget_js"], obj["payment"])
    except Exception as exc:  # noqa: BLE001
        return (
            "<html><body style='font-family:sans-serif;padding:24px;color:#c00'>"
            f"Не удалось подготовить оплату: {exc}</body></html>"
        )


class HalykConfirmView(APIView):
    """Client-side success from the Halyk widget → verify + mark trip paid."""

    permission_classes = [IsParent]

    def post(self, request):
        invoice_id = request.data.get("invoice_id")
        if not invoice_id:
            raise ValidationError({"detail": "invoice_id required"})
        prov = get_payment_provider()
        verified = "success"
        if hasattr(prov, "verify_status"):
            s = prov.verify_status(str(invoice_id))
            verified = "failed" if s == "failed" else "success"
        payment = confirm_payment(str(invoice_id), verified)
        if payment is None:
            return Response({"detail": "unknown payment"}, status=404)
        return Response({"status": payment.status})


class PaymentWebhookView(APIView):
    """POST /api/payments/webhook/{provider}/ — provider → us (no auth)."""

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request, provider):
        prov = get_payment_provider()
        try:
            event = prov.verify_webhook(request)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=400)
        payment = confirm_payment(event.provider_ref, event.status, event.raw)
        if payment is None:
            return Response({"detail": "unknown payment"}, status=404)
        return Response({"status": payment.status})


class PaymentViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin,
                     viewsets.GenericViewSet):
    """Accountant/admin read-only view of payments (finance only)."""

    serializer_class = PaymentSerializer
    permission_classes = [IsFinanceRole]
    filterset_fields = ["status", "provider"]

    def get_queryset(self):
        return Payment.objects.select_related("trip", "parent").all()


@api_view(["GET", "POST"])
@permission_classes([AllowAny])
def mock_checkout(request):
    """Tiny demo 'hosted payment page' for the mock provider.

    GET  → returns the two choices; POST ?ref=..&status=success|failed calls
    the same webhook a real bank would. Only used when PAYMENT_PROVIDER=mock.
    """
    from .services import confirm_payment

    ref = request.query_params.get("ref") or request.data.get("ref")
    if request.method == "GET":
        return Response({
            "ref": ref,
            "message": "Mock checkout. POST here with status=success|failed.",
            "success_url": f"/api/payments/mock-checkout/?ref={ref}&status=success",
            "fail_url": f"/api/payments/mock-checkout/?ref={ref}&status=failed",
        })
    status_ = request.query_params.get("status") or request.data.get("status", "success")
    payment = confirm_payment(ref, status_, {"ref": ref, "status": status_})
    if payment is None:
        return Response({"detail": "unknown payment"}, status=404)
    return Response({"status": payment.status, "trip": payment.trip_id})
