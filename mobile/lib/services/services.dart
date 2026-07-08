import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/models.dart';

final _api = ApiClient.instance;

List _results(dynamic data) =>
    data is Map && data.containsKey('results') ? data['results'] as List : (data as List);

class AuthService {
  static Future<Session> login(String email, String password) async {
    final data = await _api.post('/auth/login/', {
      'email': email,
      'password': password,
    });
    return Session.fromJson(Map<String, dynamic>.from(data));
  }

  /// Current user identity (for greeting name, role).
  static Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await _api.get('/auth/me/'));

  static Future<Session> register({
    required String email,
    required String phone,
    required String password,
    required String fullName,
  }) async {
    await _api.post('/auth/register/', {
      'email': email,
      'phone': phone,
      'password': password,
      'full_name': fullName,
    });
    return login(email, password);
  }

  /// Driver self-registration (multipart with document photos). Returns a
  /// session directly — the driver is logged in as PENDING until approved.
  static Future<Session> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String iin,
    String phone = '',
    required String carMake,
    String carModel = '',
    required String carColor,
    int? carMileage,
    required String carPlate,
    List<int>? carPhoto,
    List<int>? licensePhoto,
    List<int>? idCardPhoto,
  }) async {
    final form = FormData.fromMap({
      'email': email,
      'password': password,
      'full_name': fullName,
      'iin': iin,
      'phone': phone,
      'car_make': carMake,
      'car_model': carModel,
      'car_color': carColor,
      if (carMileage != null) 'car_mileage': carMileage,
      'car_plate': carPlate,
      if (carPhoto != null)
        'car_photo': MultipartFile.fromBytes(carPhoto, filename: 'car.jpg'),
      if (licensePhoto != null)
        'license_photo':
            MultipartFile.fromBytes(licensePhoto, filename: 'license.jpg'),
      if (idCardPhoto != null)
        'id_card_photo':
            MultipartFile.fromBytes(idCardPhoto, filename: 'id.jpg'),
    });
    final data = await _api.post('/auth/register-driver/', form);
    return Session.fromJson(Map<String, dynamic>.from(data));
  }
}

class ChildrenService {
  static Future<List<Child>> list() async {
    final data = await _api.get('/children/');
    return _results(data).map((e) => Child.fromJson(e)).toList();
  }

  static Future<Child> create({
    required String fullName,
    String? birthDate,
    String school = '',
    String grade = '',
    String note = '',
  }) async {
    final data = await _api.post('/children/', {
      'full_name': fullName,
      'birth_date': birthDate,
      'school': school,
      'grade': grade,
      'note_for_driver': note,
    });
    return Child.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<Child> update(
    int id, {
    required String fullName,
    String? birthDate,
    String school = '',
    String grade = '',
    String note = '',
  }) async {
    final data = await _api.patch('/children/$id/', {
      'full_name': fullName,
      'birth_date': birthDate,
      'school': school,
      'grade': grade,
      'note_for_driver': note,
    });
    return Child.fromJson(Map<String, dynamic>.from(data));
  }

  /// Uploads/replaces the child's photo (multipart PATCH).
  static Future<Child> uploadPhoto(
      int id, List<int> bytes, String filename) async {
    final form = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final data = await _api.patch('/children/$id/', form);
    return Child.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> remove(int id) => _api.delete('/children/$id/');
}

class MapsService {
  /// 2GIS MapGL JS key (served by the backend) for the in-app WebView map.
  static Future<String> mapKey() async {
    try {
      final data = await _api.get('/maps/config/');
      return (data['twogis_map_key'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Address autocomplete via the backend (2GIS-backed).
  static Future<List<PickedPoint>> suggest(String query) async {
    if (query.trim().length < 2) return [];
    final data = await _api.get('/maps/suggest/', query: {'q': query});
    return (data as List)
        .map((e) => PickedPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<String> reverse(double lat, double lng) async {
    try {
      final data = await _api.get('/maps/reverse/', query: {'lat': lat, 'lng': lng});
      return (data['text'] as String?) ?? 'Точка на карте';
    } catch (_) {
      return 'Точка на карте';
    }
  }

  /// Route polyline ([[lat,lng],...]) between two points, via 2GIS on backend.
  static Future<List<List<double>>> routePolyline({
    required double oLat,
    required double oLng,
    required double dLat,
    required double dLng,
  }) async {
    final data = await _api.post('/maps/route/', {
      'origin': {'lat': oLat, 'lng': oLng},
      'dest': {'lat': dLat, 'lng': dLng},
    });
    return ((data['polyline'] ?? []) as List)
        .map<List<double>>(
            (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
        .toList();
  }

  static Future<RouteEstimate> estimate({
    required double oLat,
    required double oLng,
    required double dLat,
    required double dLng,
    int? tariffId,
  }) async {
    final data = await _api.post('/maps/estimate/', {
      'origin': {'lat': oLat, 'lng': oLng},
      'dest': {'lat': dLat, 'lng': dLng},
      'tariff_id': ?tariffId,
    });
    return RouteEstimate.fromJson(Map<String, dynamic>.from(data));
  }
}

class TripsService {
  static Future<List<Trip>> list() async {
    final data = await _api.get('/trips/');
    return _results(data).map((e) => Trip.fromJson(e)).toList();
  }

  static Future<Trip> get(int id) async {
    final data = await _api.get('/trips/$id/');
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<Trip> create({
    required int childId,
    required String pickupText,
    required double pickupLat,
    required double pickupLng,
    required String dropoffText,
    required double dropoffLat,
    required double dropoffLng,
    required String scheduledAtIso,
  }) async {
    final data = await _api.post('/trips/', {
      'child': childId,
      'pickup_text': pickupText,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_text': dropoffText,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'scheduled_at': scheduledAtIso,
    });
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }

  /// Paid, unassigned orders a driver can take.
  static Future<List<Trip>> available() async {
    final data = await _api.get('/trips/available/');
    return (data as List).map((e) => Trip.fromJson(e)).toList();
  }

  static Future<Trip> accept(int id) async {
    final data = await _api.post('/trips/$id/accept/');
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<Trip> changeStatus(int id, String event, {String note = ''}) async {
    final data = await _api.post('/trips/$id/status/', {'event': event, 'note': note});
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<Trip> cancel(int id) async {
    final data = await _api.post('/trips/$id/cancel/');
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> sendLocation(int id, double lat, double lng) async {
    await _api.post('/trips/$id/location/', {'lat': lat, 'lng': lng});
  }

  static Future<void> rate(int id, int stars, {String comment = ''}) async {
    await _api.post('/trips/$id/rate/', {'stars': stars, 'comment': comment});
  }

  static Future<Map<String, dynamic>?> track(int id) async {
    try {
      final data = await _api.get('/trips/$id/track/');
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }
}

class PaymentsService {
  /// Create a payment; returns {provider, provider_ref, payment_object, redirect_url}.
  static Future<Map<String, dynamic>> create(int tripId) async {
    final data = await _api.post('/payments/create/', {'trip_id': tripId});
    return Map<String, dynamic>.from(data);
  }

  /// Emulates the hosted payment page callback (mock provider only).
  static Future<String> mockCheckout(String ref, {bool success = true}) async {
    final data = await _api.post(
      '/payments/mock-checkout/?ref=$ref&status=${success ? 'success' : 'failed'}',
    );
    return data['status'] as String;
  }

  /// Confirm a Halyk ePay payment after the widget reports success.
  static Future<String> halykConfirm(String invoiceId) async {
    final data =
        await _api.post('/payments/halyk/confirm/', {'invoice_id': invoiceId});
    return data['status'] as String;
  }

  /// Confirm a Stripe Checkout Session after the hosted page returns.
  static Future<String> stripeConfirm(String sessionId) async {
    final data =
        await _api.post('/payments/stripe/confirm/', {'session_id': sessionId});
    return data['status'] as String;
  }

  /// Choose cash: the order becomes assignable now; the driver collects the
  /// fare at the end of the ride. Returns the updated trip.
  static Future<Trip> payCash(int tripId) async {
    final data = await _api.post('/trips/$tripId/pay_cash/', {});
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }
}

class DriverService {
  static Future<List> earnings() async =>
      _results(await _api.get('/earnings/'));

  static Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await _api.get('/drivers/me/'));

  static Future<bool> setOnline(bool v) async {
    final d = await _api.post('/drivers/me/online/', {'is_available': v});
    return d['is_available'] as bool;
  }

  static Future<void> requestPayout() async => _api.post('/payouts/request/');
}

class NotificationsService {
  static Future<List<Map<String, dynamic>>> list() async {
    final data = await _api.get('/notifications/');
    return _results(data).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<int> unreadCount() async {
    try {
      final items = await list();
      return items.where((n) => n['is_read'] != true).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markRead(int id) async =>
      _api.post('/notifications/$id/read/');

  static Future<void> markAllRead() async =>
      _api.post('/notifications/read_all/');
}

class SupportService {
  static Future<List> myRequests() async =>
      _results(await _api.get('/notifications/emergency/'));

  static Future<void> send(String message, {String type = 'call_request'}) async {
    await _api.post('/notifications/emergency/', {
      'type': type,
      'message': message,
    });
  }
}

class AddressService {
  /// Recently used addresses (most recent first).
  static Future<List<PickedPoint>> recent() async {
    final data = await _api.get('/auth/addresses/');
    return _results(data)
        .map((e) => PickedPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> save(PickedPoint p) async {
    final label = p.text.length > 40 ? '${p.text.substring(0, 40)}…' : p.text;
    try {
      await _api.post('/auth/addresses/', {
        'label': label,
        'text': p.text,
        'lat': p.lat,
        'lng': p.lng,
      });
    } catch (_) {
      // Saving a recent address is best-effort; never block the flow.
    }
  }
}

class WalletService {
  static Future<Map<String, dynamic>> balance() async =>
      Map<String, dynamic>.from(await _api.get('/wallet/'));

  static Future<List> transactions() async =>
      _results(await _api.get('/wallet/transactions/'));

  /// Start a bank top-up → {ref, provider, payment_object, redirect_url}.
  static Future<Map<String, dynamic>> topUpCreate(num amount) async {
    final data = await _api.post('/wallet/topup/create/', {'amount': amount});
    return Map<String, dynamic>.from(data);
  }

  /// Mock bank checkout callback (success/fail).
  static Future<String> topUpCheckout(String ref, {bool success = true}) async {
    final data = await _api.post(
      '/wallet/topup/checkout/?ref=$ref&status=${success ? 'success' : 'failed'}',
    );
    return data['status'] as String;
  }

  static Future<List> plans() async => _results(await _api.get('/wallet/plans/'));

  static Future<void> buySubscription(int planId) async =>
      _api.post('/wallet/subscriptions/buy/', {'plan_id': planId});

  static Future<List> subscriptions() async =>
      _results(await _api.get('/wallet/subscriptions/'));
}
