# OpenConnect for Mac

[Сайт](https://valeragin.github.io/openconnect-for-mac/ru/) · [Установка](INSTALL.md) · [Диагностика](TROUBLESHOOTING.md) · [English](README.md)

Клиент AnyConnect-совместимого VPN для macOS. Туннель создаёт OpenConnect.
Приложение в строке меню и CLI `ocmac` управляют входом, профилями, маршрутами и DNS.

Нужны macOS 14.4+ и доступ к совместимому шлюзу. Проект не предоставляет
VPN-серверы. Интерфейс на русском и английском. Лицензия MIT, телеметрии нет.

## Установка

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ValeraGin/openconnect-for-mac/main/install.sh)"
```

Запускайте от обычного пользователя. [Установщик](install.sh) предложит недостающие
Apple Command Line Tools и Homebrew, соберёт приложение и установит системный
помощник. Помощнику нужны права администратора. Системная установка может
прервать прежний VPN. Сборка может занять несколько минут.

Обновление установленного пакета:

```bash
brew upgrade openconnect-for-mac
ocmac app upgrade
ocmac doctor
```

Если помощник устарел, повторите `ocmac prepare && sudo ocmac install`.
Ручная установка, перенос настроек и удаление описаны в [INSTALL.md](INSTALL.md).

## Настройка

### Профиль одним файлом

Один `.ocmac` описывает одно подключение. Создайте
`~/.config/ocmac/profiles/work.ocmac` или импортируйте файл от коллеги.

```ini
[Connection]
Name = Work
Url = vpn.example.com/employees
User = your-login

[Routes]
10.0.0.0/8

[DNS]
corp.example.com = vpn

[Auth]
Password = ask
Totp = off
```

- `[Routes]`: IPv4-сети в туннель. Остальной трафик использует обычное подключение.
- `[DNS]`: домены и их резолверы. `vpn` берёт DNS-сервер из ответа шлюза.
  Поддомены включены; более длинная зона имеет приоритет.
- `[Auth]`: источники данных входа. В примере пароль и код вводятся вручную.
  Также поддерживаются связка ключей, KeePassXC и пользовательские команды.
- Поисковый суффикс шлюза — отдельный параметр. Он не определяет полный список доменов для VPN DNS.

Проверьте профиль перед подключением:

```bash
ocmac profile-check ~/.config/ocmac/profiles/work.ocmac
ocmac connect work
```

Все параметры — в [etc/example.ocmac](etc/example.ocmac). Старые форматы
`profiles.conf`, `networks.conf` и `zones.conf` доступны через CLI.
Экспорт переводит одно старое подключение в самостоятельный `.ocmac`.

### Своя форма входа

```bash
ocmac connect work --teach
```

Пройдите веб-вход организации. После успешного входа выберите, сохранять ли
правила формы, пароль в связке ключей и источник одноразового кода. Само сохранение
профиля не сохраняет пароль. Значения пароля и TOTP-секрета хранятся в хранилище
учётных данных, а не в профиле.

`ocmac learn work` открывает ручную разметку формы. Правилами также управляют
`ocmac rules show`, `ocmac rules import` и `ocmac rules clear`.
Многошаговые формы и свои команды получения секретов описаны в [INSTALL.md](INSTALL.md).

### HostScan / CSD

Если шлюз требует проверку устройства, получите утверждённый организацией wrapper.
`CsdWrapper` указывает на файл, `CsdScriptBase64` содержит скрипт внутри профиля.
Открытие и проверка файла его не исполняют. При подключении могут выполняться
CSD и команды получения секретов: проверяйте конфигурацию от других людей.

```bash
ocmac prepare
sudo ocmac install
ocmac csd-status work
```

Системная копия должна совпадать с профилем. Встроенный скрипт переносится вместе
с файлом, но всё равно требует системной подготовки. [Пример wrapper](etc/csd-wrapper.sh)
содержит образец результатов, а не готовую оценку состояния вашего устройства.

### Импорт и экспорт

```bash
ocmac import team.ocmac
ocmac import cisco.xml
ocmac export work team.ocmac
```

Cisco XML переносит адреса серверов, а не маршруты, DNS или данные входа.
Экспорт `.ocmac` сохраняет маршруты, DNS, правила формы и встроенный CSD.
Секреты из хранилищ он не извлекает. Перед передачей проверьте User, локальные
пути и пользовательские команды. Корпоративную конфигурацию передавайте внутри команды.

### Режим SOCKS

`[Connection] Mode = proxy` использует `ocproxy` вместо системного туннеля.
Нужен `brew install ocproxy`. В этом режиме не устанавливаются VPN-маршруты
и DNS-зоны. Укажите `[Proxy] Port = 11080` и выберите, включать ли системный SOCKS.

## Команды

```bash
ocmac connect work
ocmac connect work --teach
ocmac disconnect
ocmac pause
ocmac resume
ocmac status --json
ocmac doctor
ocmac logs -n 100
ocmac autoconnect resume
ocmac import work.ocmac
ocmac export work team.ocmac
ocmac report report.txt
```

Полный список — `ocmac help`. Приложение читает `status --json`.
`doctor` не меняет систему. Проверяйте отчёты перед публикацией.

## Жизненный цикл соединения

- `autoconnect resume` восстанавливает последнее выбранное соединение после обрыва.
- `autoconnect manual` запрещает новые автоматические входы.
- `autoconnect always work` выбирает профиль при входе в систему.
- `pause` снимает маршруты и DNS-настройки приложения, сохраняя сессию.
- `disconnect` сбрасывает выбранное соединение и оставляет VPN выключенным.

Супервизор следит за соединением и повторяет попытки с нарастающей задержкой.
Истёкшая SSO-сессия может потребовать участия пользователя. Окно входа
автоматически не открывается.

## Устройство проекта

| Компонент | Назначение |
| --- | --- |
| `app/` | Приложение SwiftUI/AppKit в строке меню, без root |
| `auth/` | WebKit SSO, правила форм, окна учётных данных и QR |
| `bin/ocmac` | Bash CLI и супервизор соединения |
| `libexec/ocmac-helper` | Проверяемые привилегированные операции, настройка и очистка туннеля |
| OpenConnect | Транспорт TLS/DTLS |

Помощник получает cookie через stdin. Он учитывает свои маршруты и DNS-записи
и удаляет их при отключении. Правило sudoers разрешает запуск помощника,
а не произвольного shell. Супервизор работает как пользовательский LaunchAgent.

## Разработка

```bash
ocmac selftest
ocmac-auth --selftest
ocmac-auth --learn-selftest
python3 website/build.py --url https://valeragin.github.io/openconnect-for-mac/
python3 website/check.py
```

Сборка GUI: `bash app/make-app.sh`. Установщик выполняет сборку из исходников.
Тесты используют временное состояние, заглушки помощника и тестовые шлюзы;
они не подтверждают совместимость со всеми рабочими провайдерами входа.
Правила участия — [CONTRIBUTING.md](CONTRIBUTING.md).

## Совместимость и ограничения

- Используется на macOS 26, Apple Silicon, с AnyConnect-совместимым шлюзом и Keycloak.
- Минимальная версия сборки — macOS 14.4. Intel и macOS 14.4–15 на реальных устройствах не проверены.
- Чистая установка и первый вход на другом Маке не проверены.
- ocserv и тестовые SSO-формы не подтверждают совместимость с реальными Okta и Microsoft Entra ID.
- Адрес IPv6 туннеля может настраиваться; маршруты IPv6 не управляются.
- Требования HostScan и авторизации зависят от шлюза.
- Установка и удаление системной части могут прервать активное соединение.

## Документация

[Подключение](assets/ru/connection.png) · [Мастер](assets/ru/setup.png) · [Настройки](assets/ru/profile.png) · [Вход](assets/ru/login.png) · [Сеть](assets/ru/network.png)

Настоящие окна сняты в фоне на демонстрационных профилях. Системные контролы
неактивны. [Происхождение кадров](website/ASSETS.md).

[Установка](INSTALL.md) · [Диагностика](TROUBLESHOOTING.md) · [История изменений](CHANGELOG.md) · [Безопасность](SECURITY.md) · [Лицензия](LICENSE)

Независимый проект. Не связан с Cisco и проектом OpenConnect.
AnyConnect обозначает совместимость протокола.
