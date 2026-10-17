# ProBro — macOS-песочница для приложений App Store

Заготовка, с которой можно делать и выкладывать приложения в App Store **без своего Mac**.
Вся работа с Xcode идёт на macOS-раннерах GitHub Actions (`macos-26`, Xcode 26).
С 28 апреля 2026 года App Store Connect принимает только сборки из Xcode 26.

Что внутри:

| Что | Где | Зачем |
|---|---|---|
| SwiftUI-приложение для iOS и macOS | `App/`, `project.yml` | Один таргет на обе платформы, проект генерируется XcodeGen |
| App Sandbox для Mac App Store | `Config/ProBro-macOS.entitlements` | Mac App Store без песочницы не принимает |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy` | Обязателен для App Store |
| CI | `.github/workflows/ci.yml` | Сборка и тесты на macOS и iOS Simulator на каждый push |
| Рабочий стол Mac из Windows | `.github/workflows/macos-desktop.yml` | Экран macOS с Xcode и симулятором в VNC-клиенте на Windows |
| Интерактивный Mac по SSH | `.github/workflows/macos-sandbox.yml` | Удалённый терминал на настоящем macOS с Xcode |
| Выгрузка в App Store Connect | `.github/workflows/release.yml`, `scripts/release.sh` | Архив, подпись и upload в TestFlight/App Store |

## 0. Рабочий стол Mac из Windows (VNC)

Workflow запускает macOS-раннер с Xcode и включает на нём Screen Sharing.
Затем подключает раннер к вашей приватной сети Tailscale. В интернет экран не открывается,
его видят только ваши устройства в Tailscale.

Однократная подготовка:

1. Зарегистрируйтесь в [Tailscale](https://tailscale.com) (бесплатно), установите Tailscale для Windows и войдите.
2. В админке Tailscale: **Settings → Keys → Generate auth key**, включите **Reusable** и **Ephemeral**.
   Ephemeral-устройства сами удаляются из сети после выключения раннера.
3. Установите на Windows [TigerVNC Viewer](https://tigervnc.org). Подойдёт и TightVNC, нужен клиент с обычным VNC-паролем.
4. В репозитории откройте **Settings → Secrets and variables → Actions** и добавьте секреты:

   | Секрет | Значение |
   |---|---|
   | `TAILSCALE_AUTHKEY` | ключ из шага 2 (`tskey-auth-...`) |
   | `VNC_PASSWORD` | пароль для VNC, **не длиннее 8 символов** (так устроен протокол VNC) |

Запуск:

1. **Actions → macOS desktop (VNC) → Run workflow**, укажите, сколько минут держать Mac (до 350).
2. Подождите 1–2 минуты, откройте лог шага *Keep desktop alive*. Там будет адрес вида `probro-mac-12:5900`
   (или IP `100.x.y.z:5900`).
3. Откройте TigerVNC Viewer, введите этот адрес и `VNC_PASSWORD`.
4. Работайте в Xcode, как на обычном Mac. Проект уже сгенерирован в `~/work/ProBro/ProBro`.
5. **Закоммитьте и запушьте изменения до конца сессии**: после неё машина удаляется со всеми файлами.
   Чтобы завершить раньше, создайте на рабочем столе Mac файл `STOP` или отмените запуск в Actions.

Без секретов workflow только проверяет, что VNC показывает экран, и завершается.

Ограничения:

- Экран 1024×768.
- Пароль пользователя macOS `runner` неизвестен и не меняется. `sudo` в Терминале работает без пароля,
  но окна, которые просят пароль пользователя (например, Связка ключей), подтвердить не получится.
- Workflow выдаёт службе Screen Sharing право записывать экран и управлять вводом,
  потому что на машине CI некому нажать «Разрешить». Это меняет только временную машину GitHub.

## 1. Удалённый Mac по SSH

1. Добавьте свой публичный SSH-ключ в GitHub (Settings → SSH and GPG keys).
2. Откройте **Actions → macOS sandbox (SSH) → Run workflow** и укажите, сколько минут держать сессию (до 350).
3. В логе шага *Open SSH session* появится строка вида `ssh XXXX@nyc1.tmate.io`. Скопируйте её и подключитесь.
4. В сессии вы находитесь в клоне репозитория, проект уже сгенерирован:
   ```bash
   make test-macos          # тесты macOS-версии
   make test-ios            # тесты в iOS Simulator
   xcrun simctl list        # симуляторы
   ```
5. Изменения, сделанные в сессии, нужно закоммитить и запушить, иначе они пропадут вместе с раннером.
   Чтобы завершить сессию, выполните `touch continue` или отмените запуск.

Подключиться может только тот, кто запустил workflow (`limit-access-to-actor`).
На публичных репозиториях macOS-минуты бесплатны. На приватных они расходуют квоту с множителем ×10.

## 2. CI

Каждый push собирает приложение и прогоняет тесты на macOS и в iOS Simulator без подписи.
Секреты для этого не нужны.

## 3. Выгрузка в App Store Connect

Однократная подготовка:

1. Аккаунт Apple Developer Program ($99/год).
2. В [App Store Connect](https://appstoreconnect.apple.com) создайте приложение с Bundle ID `com.lapinio.probro`
   (или замените ID в `project.yml` на свой). Для macOS и iOS это может быть одна запись (Universal Purchase).
3. **Users and Access → Integrations → App Store Connect API**: создайте ключ с ролью **Admin**.
   Роль Admin нужна, чтобы Xcode сам выпускал облачные сертификаты для подписи. Скачайте `AuthKey_XXXX.p8`.
4. В репозитории откройте **Settings → Secrets and variables → Actions** и добавьте секреты:

   | Секрет | Значение |
   |---|---|
   | `DEVELOPMENT_TEAM` | Team ID (10 символов, Membership details) |
   | `ASC_KEY_ID` | Key ID API-ключа |
   | `ASC_ISSUER_ID` | Issuer ID (над списком ключей) |
   | `ASC_KEY_P8` | Полное содержимое файла `.p8` |

Выпуск: **Actions → Release to App Store Connect → Run workflow**, выберите `ios`, `macos` или `both`.
Номер сборки берётся из номера запуска workflow. Версия задаётся в `MARKETING_VERSION` в `project.yml`.
Через 10–30 минут после загрузки сборка появится в TestFlight.

## Если у вас всё-таки есть Mac

```bash
make open          # установит XcodeGen, сгенерирует и откроет проект
make test-macos
```

## Как сделать своё приложение

- Название, Bundle ID, категорию и минимальные версии ОС задайте в `project.yml`.
  `ProBro.xcodeproj` не коммитится, он генерируется из `project.yml`.
- Код лежит в `App/Sources`, ресурсы и иконки в `App/Resources/Assets.xcassets` (сейчас там заглушка).
- Возможности песочницы (сеть, файлы, камера и т.д.) добавляйте в `Config/ProBro-macOS.entitlements`,
  но только те, что приложение реально использует: ревью App Store их проверяет.
