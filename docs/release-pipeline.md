# Релизный пайплайн: сборка, подпись и загрузка в App Store без личного Mac

Всё гоняется на macOS-раннере GitHub Actions. Личный Mac не нужен. Запуск —
вручную из вкладки **Actions → Release to TestFlight → Run workflow**.

Пайплайн уже в репозитории:
- `.github/workflows/release.yml` — релизный workflow (ручной запуск).
- `ios/fastlane/Fastfile` — лейны `certs` (разово) и `release`.
- `ios/fastlane/Appfile`, `Matchfile` — конфигурация (значения из секретов).
- `ios/Gemfile` — fastlane.

## Что нужно сделать ОДИН раз (после оплаты Apple Developer Program)

### 1. Apple Developer Program
Оплатить $99/год на developer.apple.com. Узнать свой **Team ID** (10 символов) в
Membership. Это снимает корневой блокер.

### 2. Bundle ID
В `ios/project.yml` заменить `bundleIdPrefix: com.example` на свой
(напр. `com.вашеимя`). Полный App ID станет `com.вашеимя.ResellScanner` —
зарегистрировать его в Certificates, Identifiers & Profiles (или match создаст сам).

### 3. App Store Connect API key (авторизация CI к Apple, без 2FA)
App Store Connect → Users and Access → **Integrations → App Store Connect API** →
сгенерировать ключ с ролью **App Manager**. Скачать файл `AuthKey_XXXX.p8`
(даётся один раз). Запомнить **Key ID** и **Issuer ID**.

### 4. Приватный репозиторий для сертификатов (match)
Создать **приватный** репозиторий, напр. `resell-scanner-certs` (пустой).
Сюда match положит зашифрованные сертификаты и профили. Доступ к нему из CI —
по Personal Access Token (PAT) с правом на этот репо.

### 5. Создать запись приложения
App Store Connect → Apps → **+** → New App. Bundle ID = из шага 2,
SKU любой, Primary Language English.

### 6. Подписки (RevenueCat)
- App Store Connect → ваше приложение → **Subscriptions**: создать группу и два
  продукта auto-renewable: `$rc_monthly` ($6.99/мес) и `$rc_annual` ($39.99/год).
- RevenueCat: проект → добавить App Store app (bundle id + ASC API key) →
  Entitlement `pro` → Offering с этими двумя пакетами. Скопировать **public SDK key**
  (вид `appl_xxxxx`) и вписать в `ios/ResellScanner/Services/PurchaseManager.swift`.

### 7. GitHub Secrets
Settings → Secrets and variables → Actions → New repository secret. Завести:

| Secret | Что это |
|---|---|
| `ASC_KEY_ID` | Key ID из шага 3 |
| `ASC_ISSUER_ID` | Issuer ID из шага 3 |
| `ASC_KEY_P8` | содержимое `AuthKey_XXXX.p8`, **base64** (`base64 -i AuthKey_XXXX.p8` или онлайн) |
| `APP_IDENTIFIER` | `com.вашеимя.ResellScanner` |
| `APPLE_ID` | ваш Apple ID email |
| `DEVELOPER_TEAM_ID` | Team ID (10 символов) |
| `ASC_TEAM_ID` | обычно тот же Team ID |
| `MATCH_GIT_URL` | URL приватного репо сертификатов (шаг 4) |
| `MATCH_PASSWORD` | пароль шифрования match (придумать) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 от строки `x-access-token:<PAT>` |
| `APP_SHARED_TOKEN` | значение из `secrets.local.txt` (токен воркера) |

## После первого прогона
- В лог первого запуска `bundle install` сгенерирует `ios/Gemfile.lock`. Скачайте его
  из артефактов/лога или сгенерируйте на облачном Mac (`cd ios && bundle install`) и
  закоммитьте — тогда сборки станут воспроизводимыми и кэш gems заработает.
- Подпись (CODE_SIGN_STYLE=Manual + профиль `match AppStore <bundle id>`) валидируется
  только при реальном прогоне с настоящим аккаунтом. Если экспорт упадёт на профиле —
  проверьте, что лейн `certs` отработал и профиль с таким именем создан в репо сертификатов.

## Запуск

1. **Один раз** создать сертификаты: Actions → Release → Run workflow → lane = **certs**.
   (match создаст distribution-сертификат и профиль и зашифрованно сложит в репо сертификатов.)
2. **Каждый релиз**: Actions → Release → Run workflow → lane = **release**.
   Соберёт подписанный `.ipa`, поднимет номер сборки и зальёт в **TestFlight**.
3. В App Store Connect билд появится в TestFlight через 5–15 мин (обработка).
   Оттуда: добавить в версию приложения → заполнить метаданные/скриншоты →
   **Submit for Review**.

## Скриншоты (нужны для сабмита)
Снимаются в симуляторе на macOS-раннере. Можно добавить лейн `snapshot` (fastlane
snapshot) позже; на старте проще снять вручную через облачный Mac (MacinCloud, ~$1/ч)
или одолжить Mac на час. Раскадровка 6 кадров — в `docs/aso/app-store-listing.md`.

## Альтернатива без fastlane — Xcode Cloud
Когда появится Apple Developer, можно вместо этого пайплайна включить **Xcode Cloud**
(встроенный CI Apple): подпись настраивается автоматически, не нужны match/секреты.
Настраивается в App Store Connect, привязывается к этому GitHub-репо. Этот fastlane-путь
— на случай, если хотите полный контроль и независимость от Apple-CI.
