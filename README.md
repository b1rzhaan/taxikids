# KidsTransfer — сервис безопасной перевозки детей

MVP-платформа: родители заказывают перевозку ребёнка, штатные водители выполняют
поездки, а оператор/админ/бухгалтер управляют всем через веб-кабинет.

Три приоритетных модуля: **карта и маршруты (с пробками)**, **платежи/банк**
и **ядро заказов со стейт-машиной поездки**.

## Стек

| Слой | Технология |
|---|---|
| Backend | Django 5 + DRF, JWT (SimpleJWT), Channels (WS), Celery |
| DB | PostgreSQL (в dev можно SQLite) |
| Realtime | Redis + Django Channels (live-трекинг водителя) |
| Карта | `MapProvider` порт → `MockMapProvider` / `TwoGisProvider` (пробки) |
| Платежи | `PaymentProvider` порт → `MockPaymentProvider` (далее Kaspi/Halyk/Stripe) |
| Web | Next.js 14 + Tailwind (кабинет Admin/Operator/Accountant) — ✅ готов |
| Mobile | Flutter (Parent + Driver) — ✅ готов |

## Структура

```
taxi/
├── backend/            Django API
│   ├── kidstransfer/   project (settings, urls, asgi, celery)
│   └── apps/
│       ├── accounts    User + роли + JWT + RBAC
│       ├── children    дети (CRUD родителя)
│       ├── drivers     водители, машины, тарифы, схемы зарплат
│       ├── trips       заказы, СТЕЙТ-МАШИНА, история, локации, WS, регулярные планы
│       ├── maps        MapProvider (mock + 2GIS), geocode/route/estimate
│       ├── payments    PaymentProvider (mock), create + webhook + идемпотентность
│       ├── wallet      кошелёк, транзакции, абонементы
│       ├── payouts     начисления водителям, выплаты, отчёты
│       ├── notifications уведомления, FCM-токены, SOS
│       └── statistics  дашборд, выручка, эффективность водителей
├── web/                Next.js (скоро)
├── mobile/             Flutter (скоро)
└── docker-compose.yml  backend + Postgres + Redis
```

## Запуск через Docker (рекомендуется)

Нужен установленный **Docker Desktop**.

```bash
cp .env.example .env      # при необходимости впишите TWOGIS_API_KEY
docker compose up --build
```

Поднимутся Postgres, Redis и backend. Backend сам применит миграции и засеет
демо-данные. Открыть:

- API docs (Swagger): http://localhost:8000/api/docs/
- Django admin: http://localhost:8000/admin/

## Запуск локально без Docker (SQLite)

```bash
cd backend
python -m venv .venv && ./.venv/Scripts/activate      # Windows
pip install -r requirements.txt
export USE_SQLITE=1                                    # PowerShell: $env:USE_SQLITE=1
python manage.py migrate
python manage.py seed_demo
python manage.py runserver
```

## Web-кабинет (Next.js)

```bash
cd web
cp .env.local.example .env.local     # NEXT_PUBLIC_API_BASE=http://localhost:8000/api
npm install
npm run dev                          # http://localhost:3000
```
Логин теми же demo-доступами (роли operator/admin/accountant). Карта поездок —
на Leaflet + OpenStreetMap (без ключа). Страницы: дашборд «Панель владельца»,
заказы + назначение водителя, карта активных поездок, водители, платежи, выплаты.

## Flutter-приложение (Parent + Driver)

```bash
cd mobile
flutter pub get
flutter run                # Android-эмулятор (API → 10.0.2.2:8000) или устройство
# или в браузере:
flutter run -d chrome      # API → localhost:8000
```
Один вход разводит по роли: `parent@kids.kz` → кабинет родителя (дети, заказ с
картой, оплата, live-трекинг, кошелёк), `driver@kids.kz` → кабинет водителя
(назначенные заказы, смена статусов, симуляция GPS по маршруту). Карта — на
`flutter_map` + OpenStreetMap (без ключа), маршрут рисуется из реального 2GIS.
Базовый URL API настраивается в `lib/core/config.dart`.

## Демо-логины (пароли)

| Роль | Email | Пароль |
|---|---|---|
| Admin | admin@kids.kz | admin12345 |
| Operator | operator@kids.kz | operator12345 |
| Accountant | accountant@kids.kz | accountant12345 |
| Driver | driver@kids.kz | driver12345 |
| Parent | parent@kids.kz | parent12345 |

## Проверка сквозного сценария

```bash
cd backend && USE_SQLITE=1 DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  python smoke_test.py
```
Прогонит: логин → расчёт маршрута с пробками → создание заказа → оплата (mock
webhook) → назначение водителя → все статусы поездки → начисление водителю →
дашборд бухгалтера.

## Ключевые эндпоинты

- `POST /api/auth/login/`, `POST /api/auth/register/`, `GET /api/auth/me/`
- `GET/POST /api/children/`
- `POST /api/maps/estimate/` — маршрут + пробки + цена
- `GET/POST /api/trips/`, `POST /api/trips/{id}/status/`, `/assign/`, `/cancel/`, `/location/`
- `WS /ws/trips/{id}/?token=<jwt>` — live-трекинг
- `POST /api/payments/create/`, `POST /api/payments/webhook/{provider}/`
- `GET /api/wallet/`, `POST /api/wallet/topup/`, `/wallet/subscriptions/buy/`
- `GET /api/payouts/`, `POST /api/payouts/`, `/payouts/{id}/mark-paid/`
- `GET /api/statistics/dashboard/`

## Замена провайдеров

- Карта: `MAP_PROVIDER=twogis` + `TWOGIS_API_KEY=...` в `.env`
- Платежи: `PAYMENT_PROVIDER=kaspi` (после реализации адаптера в `apps/payments/providers/`)
