// Plain data models mapped 1:1 to the Django API payloads.

/// A chosen or suggested address (from 2GIS suggest, recents, or map tap).
class PickedPoint {
  final double lat;
  final double lng;
  final String text;
  const PickedPoint(this.lat, this.lng, this.text);

  factory PickedPoint.fromJson(Map<String, dynamic> j) => PickedPoint(
    (j['lat'] as num).toDouble(),
    (j['lng'] as num).toDouble(),
    j['text'] ?? j['label'] ?? '',
  );
}

class Session {
  final String access;
  final String refresh;
  final String role;
  final int userId;
  final String email;

  Session({
    required this.access,
    required this.refresh,
    required this.role,
    required this.userId,
    required this.email,
  });

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    access: j['access'],
    refresh: j['refresh'],
    role: j['role'] ?? '',
    userId: j['user_id'] ?? 0,
    email: j['email'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'access': access,
    'refresh': refresh,
    'role': role,
    'user_id': userId,
    'email': email,
  };

  Session copyWith({String? access, String? refresh}) => Session(
    access: access ?? this.access,
    refresh: refresh ?? this.refresh,
    role: role,
    userId: userId,
    email: email,
  );
}

class Child {
  final int id;
  final String fullName;
  final int? age;
  final String school;
  final String grade;
  final bool isPrimary;
  final String noteForDriver;
  final String? birthDate;
  final String? photo;

  Child({
    required this.id,
    required this.fullName,
    this.age,
    required this.school,
    required this.grade,
    required this.isPrimary,
    required this.noteForDriver,
    this.birthDate,
    this.photo,
  });

  factory Child.fromJson(Map<String, dynamic> j) => Child(
    id: j['id'],
    fullName: j['full_name'] ?? '',
    age: j['age'],
    school: j['school'] ?? '',
    grade: j['grade'] ?? '',
    isPrimary: j['is_primary'] ?? false,
    noteForDriver: j['note_for_driver'] ?? '',
    birthDate: j['birth_date'],
    photo: j['photo'],
  );
}

class RouteEstimate {
  final int distanceM;
  final double distanceKm;
  final int durationMin;
  final bool hasTraffic;
  final String provider;
  final num price;
  final int? tariffId;
  final List<List<double>> polyline;

  RouteEstimate({
    required this.distanceM,
    required this.distanceKm,
    required this.durationMin,
    required this.hasTraffic,
    required this.provider,
    required this.price,
    required this.tariffId,
    required this.polyline,
  });

  factory RouteEstimate.fromJson(Map<String, dynamic> j) => RouteEstimate(
    distanceM: j['distance_m'] ?? 0,
    distanceKm: (j['distance_km'] ?? 0).toDouble(),
    durationMin: j['duration_min'] ?? 0,
    hasTraffic: j['has_traffic'] ?? false,
    provider: j['provider'] ?? '',
    price: j['price'] ?? 0,
    tariffId: j['tariff_id'],
    polyline: ((j['polyline'] ?? []) as List)
        .map<List<double>>(
          (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
        )
        .toList(),
  );
}

class DriverInfo {
  final int id;
  final String fullName;
  final String phone;
  final String photo;
  final String rating;
  final int experienceYears;
  final bool hasChildSeat;
  final Map<String, dynamic>? vehicle;

  DriverInfo({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.photo,
    required this.rating,
    required this.experienceYears,
    required this.hasChildSeat,
    this.vehicle,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
    id: j['id'],
    fullName: j['full_name'] ?? '',
    phone: j['phone'] ?? '',
    photo: j['photo'] ?? '',
    rating: '${j['rating'] ?? ''}',
    experienceYears: j['experience_years'] ?? 0,
    hasChildSeat: j['has_child_seat'] ?? false,
    vehicle: j['vehicle'],
  );
}

class Trip {
  final int id;
  final String? childName;
  final String? driverName;
  final Child? child;
  final List<Child> children;
  final DriverInfo? driver;
  final String pickupText;
  final String dropoffText;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String scheduledAt;
  final String status;
  final String paymentStatus;
  final String paymentMethod; // 'card' | 'cash'
  final String priceAmount;
  final int routeDistanceM;
  final int routeDurationS;
  final List<List<double>> polyline;
  final int? myRating;

  Trip({
    required this.id,
    this.childName,
    this.driverName,
    this.child,
    this.children = const [],
    this.driver,
    required this.pickupText,
    required this.dropoffText,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.scheduledAt,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod = 'card',
    required this.priceAmount,
    required this.routeDistanceM,
    required this.routeDurationS,
    required this.polyline,
    this.myRating,
  });

  static double _d(dynamic v) => (v ?? 0).toDouble();

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: j['id'],
    childName: j['child_name'] ?? (j['child']?['full_name']),
    driverName: j['driver_name'] ?? (j['driver']?['full_name']),
    child: j['child'] is Map ? Child.fromJson(j['child']) : null,
    children: ((j['children'] ?? []) as List)
        .whereType<Map>()
        .map((e) => Child.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    driver: j['driver'] is Map ? DriverInfo.fromJson(j['driver']) : null,
    pickupText: j['pickup_text'] ?? '',
    dropoffText: j['dropoff_text'] ?? '',
    pickupLat: _d(j['pickup_lat']),
    pickupLng: _d(j['pickup_lng']),
    dropoffLat: _d(j['dropoff_lat']),
    dropoffLng: _d(j['dropoff_lng']),
    scheduledAt: j['scheduled_at'] ?? '',
    status: j['status'] ?? '',
    paymentStatus: j['payment_status'] ?? '',
    paymentMethod: j['payment_method'] ?? 'card',
    priceAmount: '${j['price_amount'] ?? '0'}',
    routeDistanceM: j['route_distance_m'] ?? 0,
    routeDurationS: j['route_duration_s'] ?? 0,
    polyline: ((j['route_polyline'] ?? []) as List)
        .map<List<double>>(
          (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
        )
        .toList(),
    myRating: j['my_rating'],
  );
}
