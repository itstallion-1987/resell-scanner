# App Store листинг (US storefront, английский)

Товарные знаки (eBay/Vinted/Poshmark/Depop/Mercari) — **только в описании** как factual interoperability, не в названии и сабтайтле (ревью 5.2).

## Название и сабтайтл

| Поле | Текст | Длина |
|---|---|---|
| Name (≤30) | `Resell Scanner: AI Listings` | 27 |
| Subtitle (≤30) | `Photo to listing in 30 sec` | 26 |

Запасные варианты Name: `AI Resell Scanner & Listings` (28), `Flip Scanner — AI Listings` (26).

## Promotional Text (≤170, можно менять без ревью)

> Snap 1–3 photos and get a ready-to-paste listing: title, description, keywords and a price estimate. No accounts, no integrations — just list faster and sell more.

## Description

```
Turn a photo into a ready-to-paste listing in 30 seconds.

Resell Scanner is the fastest way for resellers to create marketplace listings. Snap 1–3 photos of any item — clothes, shoes, electronics, home goods — and AI writes the whole draft for you:

• A search-optimized title that fits your platform's character limit
• A selling description in the right tone for your marketplace
• Brand, size and materials read straight from the tag
• An honest condition report — every visible flaw mentioned, nothing invented
• 8–12 keywords buyers actually search for
• A realistic price range plus a ready-made "sold comps" search query

WORKS WHEREVER YOU SELL
Copy each field with one tap and paste it into eBay, Vinted, Poshmark, Depop, Mercari or any other marketplace. Formatted output for every platform: title limits, hashtags for Vinted and Depop, bulleted details for Poshmark.

NO SETUP. NO ACCOUNTS. NO INTEGRATIONS.
Crosslisting platforms cost $29+/month, want your marketplace passwords and take a weekend to set up. Resell Scanner needs none of that. Open the app, take a photo, paste your listing. That's it.

BUILT FOR VOLUME SELLERS
Listing 10–50 items a week? Save 3–5 minutes on every single one. The tag-photo workflow nails brand, size and materials, and the honest condition notes cut down returns and disputes.

FREE TO TRY
Your first 5 listings are free. Resell Scanner Pro unlocks unlimited listings, full history, the platform switcher and one-tap "copy all" — $6.99/month or $39.99/year.

A note on accuracy: descriptions are generated from your photos. Always verify the authenticity of branded items yourself before listing — the app never makes authenticity claims.
```

## Keywords (≤100 символов)

Вариант A — безопасный (98):
```
resell,reseller,flip,flipping,thrift,thrifting,listing,maker,generator,secondhand,seller,declutter
```

Вариант B — с платформами (99, частая практика, но формально серая зона 2.3.7 — на своё усмотрение):
```
resell,flip,thrift,listing,generator,crosslist,ebay,vinted,poshmark,depop,mercari,seller,secondhand
```

`ai` и `listings` уже в Name — Apple индексирует Name+Subtitle+Keywords вместе, не дублируем.

## Категории

Primary: **Shopping** · Secondary: **Business**

## Скриншоты (6.7" обязательно; подписи сверху крупно)

| # | Экран | Подпись |
|---|---|---|
| 1 | Результат с заполненными полями (hero) | Photo → listing in 30 seconds |
| 2 | Камера, баннер про бирку, 2 миниатюры | Snap 1–3 angles. The tag photo nails brand & size |
| 3 | Результат, палец на кнопке копирования | Copy every field in one tap |
| 4 | **Не-одежда**: наушники/консоль в результате | Clothes, shoes, electronics — everything you flip |
| 5 | Переключатель платформ (меню открыто) | One draft — formatted for any marketplace |
| 6 | Цена + sold comps query | Honest price estimate + sold-comps check |

Скриншот 4 обязателен — клин против лёгких конкурентов, покрывающих только одежду.

## App Privacy (анкета в App Store Connect)

| Тип данных | Собирается? | Назначение | Linked to user | Tracking |
|---|---|---|---|---|
| Photos | **Нет** (передаются для обработки, не хранятся после ответа — под определение Apple «collected» не попадает, если воркер не логирует) | — | — | — |
| Device ID (анонимный UUID) | Да | App Functionality (лимиты) | Not linked | Нет |
| Purchase History (RevenueCat) | Да | App Functionality | Not linked | Нет |

В privacy policy явно сказано: фото уходят на сервер обработки и не сохраняются.

## Notes for App Review

```
Resell Scanner generates marketplace listing drafts from item photos.
- Photos are sent to our Cloudflare Worker which calls the Anthropic API; photos are not stored after the response is returned.
- The app makes no authenticity claims about branded items; a disclaimer is shown on every result screen.
- Demo: open the app, allow camera, photograph any household item (or pick from library), tap the sparkles button. First 5 listings are free, no account required.
- Subscription "Pro" (monthly/yearly) is managed via RevenueCat; sandbox account not required to test the free tier.
```
