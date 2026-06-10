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
- **Модель:** `claude-sonnet-4-6` (задаётся в `proxy/wrangler.toml` → `MODEL`). Выбрана по критерию приёмки «себестоимость ≤ $0.04»: 3 фото ≈ 4.8K входных токенов + ~0.8K выходных ≈ **$0.027** на объявление. Opus 4.8 даёт ~$0.05 — за бюджетом. Параметры вызова: structured outputs (`output_config.format` с JSON-схемой — модель не может ответить не-JSON'ом), `thinking: disabled` + `effort: low` ради латентности ≤ 5 с, системный промпт кэшируется (`cache_control`).
- **Лимиты:** Free — 5 объявлений суммарно на устройство (счётчик в KV, device-ID хранится в Keychain и переживает переустановку); дневной потолок 300 для всех. Попытка списывается только при успешной генерации.
- **Подписка:** RevenueCat, entitlement `pro`. Воркер проверяет статус server-side через RevenueCat REST API (кэш 1 час в KV) — клиентскому флагу не доверяет.
- **Запреты в системном промпте:** никаких вердиктов подлинности, гарантий продажи/цены, оценки ювелирки/драгметаллов, медицинских заявлений. Состояние — только по видимому. На экране результата — дисклеймер про подлинность.

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

## Сабмит — не забыть

- **Privacy:** в App Privacy указать «Photos — App Functionality, не linked to identity» (фото уходят на сервер обработки и не хранятся). В описании политики прямо сказать: фото передаются на сервер для генерации, не сохраняются.
- **Товарные знаки (ревью 5.2):** в названии и сабтайтле не использовать «eBay/Vinted/Poshmark» — только в описании функциональности.
- **Скриншоты под ASO-запросы** (resell scanner, ebay listing generator, ai listing maker…): минимум один скриншот с **не-одеждой** (электроника/предметы быта) — клин против ThreadMint AI.
- Позиционирование листинга: «анти-платформа» — *no accounts, no integrations — photo to listing in 30 seconds*, цена $6.99 против $29+ у кросслистинг-платформ.

## Бэклог (зафиксировано, в MVP не тащить)

- **v1.1 — «антикварный режим»:** второй вариант системного промпта + переключатель режима (что за вещь, эпоха, история, ориентир ценности).
- **R1 (v1.1, опционально):** eBay Browse API для sold comps.
- **v2 — кросслистинг-форматтер** (одна вещь → черновики на 3 платформы) — главный платный апселл.
