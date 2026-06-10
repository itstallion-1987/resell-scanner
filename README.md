# Resell Scanner — AI-сканер для перепродавцов (MVP)

Фото вещи (1–3 ракурса) → один тап → за 3–5 секунд готовый черновик объявления для eBay / Vinted / Poshmark / Depop / Mercari: заголовок, описание, характеристики, ключевые слова, ориентир цены. Всё копируется по полям. **No accounts, no integrations, no setup.**

## Структура

```
proxy/   Cloudflare Worker (TypeScript) — единственное место с API-ключом Anthropic
ios/     SwiftUI-приложение, iOS 17+ (XcodeGen-манифест project.yml)
site/    Лендинг + Privacy Policy (деплой: npx wrangler pages deploy site)
docs/    Тест-план, ASO-листинг App Store (docs/aso/), варианты иконки (docs/icons/)
```

Юнит-тесты воркера (без реальных вызовов API): `cd proxy && npm test`.

## Архитектура

- **Один vision-вызов на объявление** (до 3 фото в одном запросе). Переключение платформы на экране результата — локальное переформатирование (`PlatformFormatter`), без нового вызова.
- **Модель:** `claude-sonnet-4-6` (задаётся в `proxy/wrangler.toml` → `MODEL`). Выбрана по критерию приёмки «себестоимость ≤ $0.04»: 3 фото ≈ 4.8K входных токенов + ~0.8K выходных ≈ **$0.027** на объявление. Opus 4.8 даёт ~$0.05 — за бюджетом. Параметры вызова: structured outputs (`output_config.format` с JSON-схемой — модель не может ответить не-JSON'ом), `thinking: disabled` + `effort: low` ради латентности ≤ 5 с. `cache_control` на системном промпте стоит «на вырост»: текущий промпт (~750 токенов) короче минимума кэширования Sonnet (2048 т.) и фактически не кэшируется — экономия включится, если промпт вырастет.
- **Лимиты:** Free — 5 объявлений суммарно на устройство, дневной потолок 300 на устройство (счётчики в KV, device-ID в Keychain переживает переустановку). Плюс **глобальный дневной потолок** `GLOBAL_DAILY_CAP` (по умолчанию 5000) — предохранитель бюджета Anthropic, не зависящий от device-ID: при достижении воркер отдаёт 503 ещё до вызова модели. Free-попытка списывается только при удачном распознавании (`recognized:true`); глобальный — при любой успешной генерации. Device-счётчики на KV — «мягкие» (возможен недосчёт при гонке); жёсткая граница расходов — глобальный потолок + Cloudflare Rate Limiting + spend limit в консоли Anthropic.
- **Подписка:** RevenueCat, entitlement `pro`. Воркер проверяет статус server-side через RevenueCat REST API — клиентскому флагу не доверяет. Кэш: подтверждённый Pro — 1 час, отрицательный — 60 с (Pro открывается сразу после покупки), не-2xx от RevenueCat не кэшируется.
- **Язык:** запрос несёт код локали устройства (`language`); описание генерируется на языке продавца (de/fr/pl…), поля и enum остаются машинными.
- **Аналитика:** Workers Analytics Engine (без сторонних SDK) — на каждое объявление пишутся платформа, recognized, confidence, токены/себестоимость, latency; событийная воронка через `POST /v1/event` (paywall_shown, copy_all, limit_reached…).
- **Контент-гигиена:** ответ модели прогоняется через серверный `sanitizeDraft` — из title/description/condition_details вырезаются ссылки и телефоны (анти-инъекция через note/текст на фото). Вердикты подлинности, гарантии цены, оценка ювелирки, мед-заявления запрещены системным промптом; на экране результата — дисклеймер.

## Деплой воркера

```bash
cd proxy
npm install
npx wrangler kv namespace create LIMITS        # id → в wrangler.toml
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put REVENUECAT_SECRET      # секретный ключ RevenueCat
npx wrangler secret put APP_SHARED_SECRET      # любой длинный случайный токен
npx wrangler deploy
```

Локальная разработка: `npx wrangler dev` (для теста без подписки поставьте `DEV_MODE = "1"` в wrangler.toml и шлите заголовок `X-Debug-Pro: 1`).

### Тест на наборах фото (шаг 1 порядка работы)

Положите кейсы в `proxy/test/sets/<имя>/*.jpg` (одежда с биркой и без, обувь, **электроника и предметы быта — обязательно**, плохой свет, «не товар») и запустите:

```bash
node test/run-test-set.mjs http://localhost:8787 ebay
```

Скрипт печатает latency, распознанный бренд, заголовок и себестоимость по токенам; итоги — в `test/results.json`. Критерии: бренд+категория верны ≥ 85% при наличии бирки; видимые дефекты в `condition_details` в 100% случаев; cost ≤ $0.04.

## Сборка iOS (нужен Mac)

```bash
brew install xcodegen
cd ios && xcodegen generate && open ResellScanner.xcodeproj
```

Перед сборкой заменить плейсхолдеры:

| Где | Что |
|---|---|
| `ios/project.yml` | `bundleIdPrefix` |
| `Services/APIClient.swift` | `baseURL` (URL воркера) и `appToken` (= APP_SHARED_SECRET) |
| `Services/PurchaseManager.swift` | публичный Apple API-ключ RevenueCat |
| `Views/SettingsView.swift` | ссылка на Privacy Policy |

В RevenueCat: entitlement `pro`, offering с пакетами `$rc_annual` ($39.99) и `$rc_monthly` ($6.99); продукты создать в App Store Connect.

## Маппинг на спецификацию

| Требование | Где реализовано |
|---|---|
| 1 vision-вызов, до 3 фото | `proxy/src/index.ts` (один `messages.create`) |
| API-ключ только в прокси | секрет `ANTHROPIC_API_KEY` у воркера; в приложении ключа нет |
| Device-лимиты, проверка receipt | `limits.ts` (KV), `entitlements.ts` (RevenueCat REST) |
| Подсказка «сними бирку» | онбординг слайд 2 + баннер в `ScanView` после 1-го кадра |
| Цена — честный ориентир | схема требует `price_range.note` + `sold_comps_query` |
| Clipboard-first | `ResultView`: копирование по полям + «Copy all» (Pro) |
| Тон платформ одним параметром | `prompt.ts` (таблица тонов в системном промпте) + `PlatformFormatter` локально |
| Paywall: после 1-го объявления / 6-е / переключатель | `AppState.consumeFirstListingPaywallTrigger`, `ScanView.generate`, `ResultView.platformBinding` |
| Free 5 / Pro $6.99/мес, $39.99/год (якорь — год) | воркер `FREE_TOTAL_LIMIT`, `PaywallView` |
| История локально (SwiftData) | `Models/Listing.swift`, `HistoryView` (Pro) |

## ⚠️ Перед сабмитом — обязательные действия

Исправлено в коде по итогам коллегии: ссылки Privacy+EULA на paywall, цены только из RevenueCat (без захардкоженных), анкета Photos в docs/aso, Device ID в Settings, ссылки вынесены в `AppConfig.swift`, keywords-вариант A зафиксирован. Осталось то, что зависит от ваших аккаунтов/инфраструктуры:

1. **Заполнить плейсхолдеры** в `ios/ResellScanner/Services/AppConfig.swift` (URL воркера, `appToken`, домен Privacy Policy), `PurchaseManager.swift` (публичный ключ RevenueCat), `project.yml` (`bundleIdPrefix`). Pre-submit чек: `grep -rn "YOUR-SUBDOMAIN\|REPLACE_\|YOUR-DOMAIN\|example.com" ios/`.
2. **Задеплоить `site/`** (Cloudflare Pages) и вписать его URL в `AppConfig.privacyPolicyURL`.
3. **Cloudflare**: включить Rate Limiting Rule на `/v1/listing` (в дашборде, без релиза приложения) и **spend limit** в консоли Anthropic — глобальный потолок в коде это backstop, а не замена.
4. **App Privacy** в App Store Connect заполнить по таблице из `docs/aso/app-store-listing.md` (Photos = collected, App Functionality, Not linked).
5. **App Attest (DCAppAttestService)** — стратегически, чтобы `X-Device-ID` нельзя было подделать произвольным UUID (см. бэклог безопасности ниже).

## Бэклог безопасности (не блокеры релиза, но запланировать)

- **Durable Objects** для счётчиков лимитов вместо KV (атомарный инкремент устранит гонку TOCTOU; сейчас задокументировано как «мягкий» лимит, жёсткая граница — глобальный потолок + Cloudflare RL).
- **App Attest** для аутентификации устройства (заменяет доверие к `X-Device-ID` и статичному `APP_SHARED_SECRET`).
- **Привязка `X-RC-User-ID`** к подтверждённой идентичности устройства (сейчас используются анонимные RC-ID, перебор непрактичен, но архитектурно идентификатор не аутентифицирован).

## Сабмит — не забыть

- **Privacy:** в App Privacy указать «Photos — App Functionality, не linked to identity» (фото уходят на сервер обработки и не хранятся). В описании политики прямо сказать: фото передаются на сервер для генерации, не сохраняются.
- **Товарные знаки (ревью 5.2):** в названии и сабтайтле не использовать «eBay/Vinted/Poshmark» — только в описании функциональности.
- **Скриншоты под ASO-запросы** (resell scanner, ebay listing generator, ai listing maker…): минимум один скриншот с **не-одеждой** (электроника/предметы быта) — клин против ThreadMint AI.
- Позиционирование листинга: «анти-платформа» — *no accounts, no integrations — photo to listing in 30 seconds*, цена $6.99 против $29+ у кросслистинг-платформ.

## Бэклог (зафиксировано, в MVP не тащить)

- **v1.1 — «антикварный режим»:** второй вариант системного промпта + переключатель режима (что за вещь, эпоха, история, ориентир ценности).
- **R1 (v1.1, опционально):** eBay Browse API для sold comps.
- **v2 — кросслистинг-форматтер** (одна вещь → черновики на 3 платформы) — главный платный апселл.
