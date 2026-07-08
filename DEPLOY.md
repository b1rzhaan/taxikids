# Деплой на Render (backend) + сборка APK

Готово к деплою: `render.yaml`, прод-настройки, WhiteNoise (статика), Cloudinary
(фото), fallback без Redis. Ниже — по шагам.

## 1. Cloudinary (хранилище фото) — 5 мин
Фото детей/водителей должны храниться вне сервера (диск Render эфемерный).
1. Зарегистрируйся на https://cloudinary.com (Free).
2. Dashboard → скопируй **API Environment variable**:
   `cloudinary://<API_KEY>:<API_SECRET>@<CLOUD_NAME>`
3. Сохрани — вставишь в Render на шаге 4.

## 2. Залить код на GitHub
Render деплоит из Git-репозитория. В корне проекта:
```bash
git add .
git commit -m "Deploy: Render backend + prod config"
# создай пустой репозиторий на github.com, затем:
git remote add origin https://github.com/<ТВОЙ_ЛОГИН>/kidstransfer.git
git branch -M main
git push -u origin main
```
(`.gitignore` уже исключает секреты, node_modules, сборки — можно пушить всё.)

## 3. Создать сервисы на Render (Blueprint)
1. https://dashboard.render.com → **New +** → **Blueprint**.
2. Подключи свой GitHub-репозиторий. Render найдёт `render.yaml`.
3. Нажми **Apply** — создастся Postgres `kidstransfer-db` и веб-сервис
   `kidstransfer-api` (миграции + демо-данные выполнятся автоматически).

## 4. Добавить Cloudinary в Render
Сервис `kidstransfer-api` → **Environment** → у переменной `CLOUDINARY_URL`
вставь строку из шага 1 → **Save** (сервис передеплоится).

## 5. Готово — проверь URL
URL будет вида `https://kidstransfer-api.onrender.com`.
Открой в браузере `https://kidstransfer-api.onrender.com/api/schema/` — должна
отдаться схема. Демо-логины те же (admin@kids.kz / admin12345 и т.д.).

> ⚠️ Free-план «засыпает» после ~15 мин простоя — первый запрос после сна
> грузится 30–60 сек (потом быстро). Для теста это норм.

## 6. Собрать APK, указывающий на прод
Когда узнаешь URL, дай мне его — я соберу APK командой:
```bash
cd mobile
flutter build apk --release --dart-define=API_BASE=https://kidstransfer-api.onrender.com/api
```
APK появится в `mobile/build/app/outputs/flutter-apk/app-release.apk` — его
можно установить на любой Android-телефон и тестировать с разных устройств.

## (Опционально позже)
- Веб-кабинет: задеплоить на **Vercel** (rootDir `web`, env
  `NEXT_PUBLIC_API_BASE=https://kidstransfer-api.onrender.com/api`).
- Redis (Render **Key Value**) — если понадобится масштабирование websocket на
  несколько инстансов. Сейчас работает и без него.
- Stripe demo payments — `PAYMENT_PROVIDER=stripe`, `STRIPE_SECRET_KEY=sk_test_...`,
  `STRIPE_WEBHOOK_SECRET=whsec_...`. Это тестовый режим для демонстрации картой.
- Реальные платежи — договор с Halyk/ioka/Kaspi/CloudPayments/Kassa24 + боевые ключи в env.
