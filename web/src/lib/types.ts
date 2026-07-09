export type Role = "parent" | "driver" | "operator" | "admin" | "accountant";

export interface Session {
  access: string;
  refresh: string;
  role: Role;
  user_id: number;
  email: string;
}

export interface Paginated<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface DayPoint {
  day: string;
  trips: number;
  completed: number;
  revenue: number;
}

export interface TopDriver {
  id: number;
  full_name: string;
  phone: string;
  rating: string;
  trips_count: number;
}

export interface DashboardStats {
  trips_total: number;
  trips_active: number;
  trips_completed: number;
  trips_cancelled: number;
  clients_count: number;
  children_count: number;
  drivers_count: number;
  revenue: { total: number; today: number; week: number; month: number };
  driver_expense_total: number;
  app_income_total: number;
  payouts_pending: number;
  trips_by_day: DayPoint[];
  top_drivers: TopDriver[];
}

export interface Trip {
  id: number;
  child_name?: string;
  driver_name?: string;
  pickup_text: string;
  dropoff_text: string;
  scheduled_at: string;
  status: string;
  payment_status: string;
  payment_method?: "card" | "cash";
  price_amount: string;
  price_currency: string;
  route_distance_m?: number;
  route_duration_s?: number;
  pickup_lat?: number;
  pickup_lng?: number;
  dropoff_lat?: number;
  dropoff_lng?: number;
  parent_rating?: number | null;
  rating_comment?: string;
}

export interface Child {
  id: number;
  full_name: string;
  birth_date?: string | null;
  age?: number | null;
  school: string;
  grade: string;
  is_primary: boolean;
  photo?: string | null;
  note_for_driver?: string;
}

export interface ParentProfile {
  id: number;
  user_id: number;
  email: string;
  full_name: string;
  phone: string;
  default_address?: string;
  photo?: string | null;
  children_count?: number;
  children?: Child[];
  created_at: string;
}

export interface Driver {
  id: number;
  full_name: string;
  phone: string;
  email?: string;
  iin?: string;
  license_number?: string;
  license_expiry?: string | null;
  doc_status: string;
  is_available: boolean;
  has_child_seat?: boolean;
  rating: string;
  experience_years: number;
  hired_at?: string | null;
  photo?: string | null;
  license_photo?: string | null;
  id_card_photo?: string | null;
  vehicles?: Vehicle[];
}

export interface Vehicle {
  id: number;
  make: string;
  model: string;
  plate_number: string;
  color?: string;
  seats?: number;
  year?: number | null;
  mileage_km?: number | null;
  tech_passport?: string;
  photo?: string | null;
  is_active?: boolean;
}

export interface DriverLocation {
  id: number;
  full_name: string;
  rating: string;
  phone: string;
  photo: string | null;
  lat: number;
  lng: number;
  heading: number;
  vehicle: {
    make: string;
    model: string;
    plate_number: string;
    color?: string;
  } | null;
}

export interface Tariff {
  id: number;
  name: string;
  base_fare: string;
  per_km: string;
  per_min: string;
  min_fare: string;
  is_active: boolean;
}

export interface DriverPayout {
  id: number;
  period_start: string;
  period_end: string;
  total_amount: string;
  status: string;
  paid_at: string | null;
}

export interface DriverStats {
  earned_today: number | string;
  earned_week: number | string;
  trips_today: number;
  completed_total: number;
  pending_amount: number | string;
  reviews_count: number;
  income_by_day: { day: string; amount: number }[];
  payouts: DriverPayout[];
}

export interface TripDetail extends Trip {
  route_polyline?: [number, number][];
}

export interface Payment {
  id: number;
  trip: number;
  child_name?: string;
  provider: string;
  amount: string;
  currency: string;
  status: string;
  created_at: string;
  paid_at: string | null;
}

export interface Payout {
  id: number;
  driver_name?: string;
  period_start: string;
  period_end: string;
  total_amount: string;
  status: string;
  items_count?: number;
}
