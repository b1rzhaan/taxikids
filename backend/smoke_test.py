"""End-to-end smoke test of the core flow using DRF's test client (no server)."""
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "kidstransfer.settings")
os.environ.setdefault("USE_SQLITE", "1")

import django  # noqa: E402

django.setup()

from rest_framework.test import APIClient  # noqa: E402

c = APIClient()


def login(email, pwd):
    r = c.post("/api/auth/login/", {"email": email, "password": pwd}, format="json")
    assert r.status_code == 200, r.content
    return r.data["access"]


def auth(token):
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")


print("1) parent login")
parent = login("parent@kids.kz", "parent12345")
auth(parent)

print("2) estimate route (mock 2GIS) — distance/time/price")
r = c.post("/api/maps/estimate/", {
    "origin": {"lat": 43.2389, "lng": 76.8897},
    "dest": {"lat": 43.2565, "lng": 76.9285},
}, format="json")
assert r.status_code == 200, r.content
print("   ", {k: r.data[k] for k in ("distance_km", "duration_min", "has_traffic", "price")})

print("3) get my child")
r = c.get("/api/children/")
child_id = r.data["results"][0]["id"]

print("4) create trip")
r = c.post("/api/trips/", {
    "child": child_id,
    "pickup_text": "ул. Абая, 45", "pickup_lat": 43.2389, "pickup_lng": 76.8897,
    "dropoff_text": "Школа №25", "dropoff_lat": 43.2565, "dropoff_lng": 76.9285,
    "scheduled_at": "2026-07-02T08:00:00Z",
}, format="json")
assert r.status_code == 201, r.content
trip_id = r.data["id"]
print("   trip", trip_id, "price", r.data["price_amount"], "status", r.data["status"])

print("5) create payment (mock)")
r = c.post("/api/payments/create/", {"trip_id": trip_id}, format="json")
assert r.status_code == 200, r.content
ref = r.data["provider_ref"]
print("   redirect", r.data["redirect_url"])

print("6) mock checkout -> success (webhook)")
r = c.post(f"/api/payments/mock-checkout/?ref={ref}&status=success")
assert r.status_code == 200, r.content
print("   payment", r.data)

print("7) trip is paid now")
r = c.get(f"/api/trips/{trip_id}/")
print("   status", r.data["status"], "payment", r.data["payment_status"])
assert r.data["status"] == "paid"

print("8) operator assigns driver")
auth(login("operator@kids.kz", "operator12345"))
from apps.drivers.models import DriverProfile  # noqa: E402
driver = DriverProfile.objects.get(user__email="driver@kids.kz")
vehicle = driver.vehicles.first()
r = c.post(f"/api/trips/{trip_id}/assign/",
           {"driver_id": driver.id, "vehicle_id": vehicle.id}, format="json")
assert r.status_code == 200, r.content
print("   status", r.data["status"])

print("9) driver runs the trip through completion")
auth(login("driver@kids.kz", "driver12345"))
for event in ["depart", "arrive", "pick_up", "start", "deliver", "complete"]:
    r = c.post(f"/api/trips/{trip_id}/status/", {"event": event}, format="json")
    assert r.status_code == 200, (event, r.content)
    print(f"   {event:9s} -> {r.data['status']}")

print("10) driver earning accrued")
r = c.get("/api/earnings/")
print("   earnings", [(e["trip"], e["amount"], e["status"]) for e in r.data["results"]])

print("11) accountant dashboard")
auth(login("accountant@kids.kz", "accountant12345"))
r = c.get("/api/statistics/dashboard/")
assert r.status_code == 200, r.content
d = r.data
print("   trips_total", d["trips_total"], "completed", d["trips_completed"],
      "revenue.total", d["revenue"]["total"], "driver_expense", d["driver_expense_total"],
      "app_income", d["app_income_total"])

print("\nALL SMOKE CHECKS PASSED")
