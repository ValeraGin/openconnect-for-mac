import SwiftUI
import AppKit

/// Secondary screens use the same fixed window; all operations affect demo state only.
struct CapabilitiesView: View {
    @ObservedObject var model: DemoModel
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    private func option<T>(_ key: WritableKeyPath<DemoOptions, T>, _ fallback: T) -> Binding<T> {
        Binding(get: { model.draft?.options[keyPath: key] ?? fallback }, set: { model.draft?.options[keyPath: key] = $0 })
    }
    private func input(_ ru: String, _ en: String, _ key: WritableKeyPath<DemoOptions, String>, hint: String = "") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t(ru, en)).font(.system(size: 12))
            SingleLineInput(text: option(key, ""), label: t(ru, en), placeholder: hint).frame(height: 26)
        }
    }
    private func note(_ ru: String, _ en: String) -> some View {
        Text(t(ru, en)).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    var body: some View {
        Form {
            if !model.notice.isEmpty {
                Section { Text(model.notice).font(.system(size: 12)).foregroundStyle(LabColor.accent).fixedSize(horizontal: false, vertical: true) }
            }
            if let detail = model.detail {
                switch detail {
                case .sources: sources
                case .totpOptions: totpOptions
                case .qrImport: qrImport
                case .dns: dns
                case .rules: rules
                case .learning: learning
                case .compatibility: compatibility
                case .profiles: profiles
                case .transfer: transfer
                case .setup: setup
                case .logs: logs
                case .report:
                    Section {
                        Text(model.diagnosticReport).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        Button(t("Сохранить тестовый отчёт…", "Save sample report…")) { saveSample(model.diagnosticReport, name: "ocmac-demo-report.txt") }
                        note("Перед отправкой проверьте файл. Реальные отчёты скрывают адреса, домены и логины.", "Review the file before sharing. Production reports redact addresses, domains and usernames.")
                    }
                case .runtime: runtime
                case .filePreview:
                    Section {
                        input("Имя файла", "File name", \.fileName)
                        Button(t("Экспортировать тестовый файл…", "Export sample file…")) { saveSample(model.profilePreview, name: model.draft?.options.fileName ?? "profile.ocmac") }.disabled(!model.valid)
                    }
                    Section { Text(model.profilePreview).font(.system(size: 11, design: .monospaced)).textSelection(.enabled) }
                }
            } else if model.page == .notifications { notifications }
            else { diagnostics }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }
    private var sources: some View {
        Group {
            Section {
                sourcePicker(t("Пароль", "Password"), option(\.passwordSource, "auto"), code: false)
                if model.draft?.options.passwordSource == "command" { input("Команда для пароля", "Password command", \.passwordCommand) }
                if model.draft?.browserLogin == true {
                    sourcePicker(t("Одноразовый код", "One-time code"), option(\.codeSource, "auto"), code: true)
                    if model.draft?.options.codeSource == "command" { input("Команда для кода", "Code command", \.codeCommand) }
                }
                note("Авто: связка ключей или настроенный KeePassXC. Команды в демо не запускаются.", "Auto: Keychain or configured KeePassXC. This demo never runs commands.")
            }
            if model.draft?.options.passwordSource == "keepassxc" || model.draft?.options.codeSource == "keepassxc" {
                Section("KeePassXC") {
                    if !model.keepassUnlocked {
                        IconLabel(title: t("База закрыта", "Database locked"), icon: "lock-keyhole").foregroundStyle(LabColor.warning)
                        Button(t("Открыть тестовую базу", "Unlock sample database")) { model.keepassUnlocked = true }
                    }
                    input("Запись", "Entry", \.keepassEntry, hint: "Work/VPN")
                    input("База", "Database", \.keepassDB, hint: "~/Passwords.kdbx")
                    input("Сервис мастер-пароля в Keychain", "Master password service in Keychain", \.keepassKeychain)
                    Button(t("Проверить источник", "Check source")) {
                        model.notice = !model.keepassUnlocked ? t("Сначала откройте базу KeePassXC.", "Unlock the KeePassXC database first.") : model.extendedIssues.first ?? t("Тестовая база открыта, запись найдена.", "Sample database unlocked, entry found.")
                    }
                }
            }
            Section { input("Сервис связки ключей", "Keychain service", \.keychainService) }
            Section {
                DetailLink(model: model, destination: .totpOptions)
                note("Ввод пароля вручную и SMS требуют участия при следующем входе.", "Manual passwords and SMS require interaction on the next sign-in.")
            }
        }
    }
    private func sourcePicker(_ title: String, _ binding: Binding<String>, code: Bool) -> some View {
        Picker(title, selection: binding) {
            Text(t("Авто", "Auto")).tag("auto")
            Text(t("Связка ключей", "Keychain")).tag("keychain")
            Text("KeePassXC").tag("keepassxc")
            Text(t("Команда", "Command")).tag("command")
            if code { Text("SMS").tag("sms"); Text(t("Выключено", "Off")).tag("off") }
            else { Text(t("Вводить вручную", "Ask each time")).tag("ask") }
        }
    }
    private var totpOptions: some View {
        Group {
            Section {
                Picker(t("Алгоритм", "Algorithm"), selection: option(\.algorithm, "SHA1")) {
                    ForEach(["SHA1", "SHA256", "SHA512"], id: \.self) { Text($0).tag($0) }
                }
                Picker(t("Количество цифр", "Digits"), selection: option(\.digits, "6")) {
                    ForEach(["6", "7", "8"], id: \.self) { Text($0).tag($0) }
                }
                input("Период, секунд", "Period, seconds", \.period, hint: "30")
                note("От 10 до 300 секунд. Обычно параметры подставляются при импорте QR.", "10–300 seconds. QR import normally sets these values.")
            }
            Section { DetailLink(model: model, destination: .qrImport) }
        }
    }
    private var qrImport: some View {
        Group {
            Section {
                Picker(t("Откуда взять секрет", "Secret source"), selection: $model.qrSource) {
                    Text(t("QR с экрана", "QR on screen")).tag("screen")
                    Text(t("Камера", "Camera")).tag("camera")
                    Text(t("Файл QR", "QR image file")).tag("file")
                    Text(t("Секрет / ссылка", "Secret / link")).tag("text")
                }
                note("QR с экрана и камера есть в настройках рабочего клиента; файл QR — в обучении входу. Демо показывает результат на тестовых данных.", "Production settings support screen QR and camera; Teach also accepts an image file. This demo uses sample data.")
                if model.qrSource == "text" {
                    Button(t("Вставить секрет…", "Enter secret…")) { model.openCredential(.credentialCode) }.disabled(model.dirty)
                } else {
                    Button(t("Показать тестовый результат", "Show sample result")) { model.qrDetected = true }
                }
            }
            if model.qrDetected {
                Section(t("Найдены записи", "Detected accounts")) {
                    Picker(t("Запись", "Account"), selection: $model.selectedQR) {
                        Text("VPN · alex@example.com").tag("branch")
                        Text("Lab · tester@example.com").tag("lab")
                    }
                    Text("TOTP · SHA1 · 6 · 30 s").font(.system(size: 12, design: .monospaced))
                    Button(t("Использовать тестовый секрет…", "Use sample secret…")) {
                        model.openCredential(.credentialCode); model.authSecret = DemoModel.sampleSecret
                    }.disabled(model.dirty)
                    note("Выберите одну запись из экспорта Google Authenticator. HOTP не поддерживается.", "Choose one account from a Google Authenticator export. HOTP is not supported.")
                }
            }
        }
    }
    private var dns: some View {
        Group {
            ForEach(model.draft?.zones ?? []) { zone in
                Section {
                    zoneInput(zone.id, \.zone, t("Домен", "Domain"))
                    zoneInput(zone.id, \.resolver, t("Резолвер: IP или vpn", "Resolver: IP or vpn"))
                    zoneInput(zone.id, \.port, t("Порт", "Port"))
                    Button(t("Удалить зону", "Remove zone"), role: .destructive) { model.draft?.zones.removeAll { $0.id == zone.id } }
                }
            }
            Section {
                Button(t("Добавить зону", "Add zone")) { model.draft?.zones.append(DemoZone(zone: "", resolver: "vpn", port: "53")) }
                note("vpn — DNS, полученный от шлюза. Более длинная зона имеет приоритет. Изменения вступят в силу при следующем подключении.", "vpn uses the gateway’s DNS. The longest matching zone takes priority. Changes apply on the next connection.")
            }
        }
    }
    private func zoneInput(_ id: UUID, _ key: WritableKeyPath<DemoZone, String>, _ label: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).frame(width: 130, alignment: .leading)
            SingleLineInput(text: Binding(get: { model.draft?.zones.first { $0.id == id }?[keyPath: key] ?? "" }, set: { value in
                if let index = model.draft?.zones.firstIndex(where: { $0.id == id }) { model.draft?.zones[index][keyPath: key] = value }
            }), label: label).frame(height: 26)
        }
    }
    private var rules: some View {
        Group {
            Section {
                DetailLink(model: model, destination: .learning)
                note("Отметьте поля и кнопку на форме организации. Правила могут содержать несколько шагов.", "Mark fields and buttons on the organization’s form. Rules may contain multiple steps.")
            }
            Section(t("Правила профиля", "Profile rules")) {
                TextEditor(text: option(\.rules, "")).font(.system(size: 11, design: .monospaced)).frame(height: 130)
                note("fill username|password|totp|manual · click · click! · stop. Пусто — общий файл или встроенные правила.", "fill username|password|totp|manual · click · click! · stop. Empty uses the shared file or built-in rules.")
                input("Общий файл правил", "Shared rules file", \.rulesFile)
            }
        }
    }
    private var learning: some View {
        Group {
            Section {
                Text(t("Тестовая форма · шаг \(model.learningStep + 1) из 2", "Sample form · step \(model.learningStep + 1) of 2")).font(.headline)
                note("В рабочем приложении вы отмечаете элементы настоящей страницы. Здесь можно пройти тот же выбор на тестовой форме.", "Production lets you mark elements on the real page. Try the same choices on this sample form.")
                if model.learningStep == 0 {
                    learningField("username", t("Поле пользователя", "Username field"))
                    learningField("password", t("Поле пароля", "Password field"))
                    Button(t("Пройти шаг →", "Next step →")) { model.learningStep = 1 }
                        .disabled(!model.learningSelections.isSuperset(of: ["username", "password"]))
                } else {
                    learningField("totp", t("Поле одноразового кода", "One-time code field"))
                    Button(t("Завершить разметку", "Finish mapping")) { model.finishLearning() }.disabled(!model.learningSelections.contains("totp"))
                }
                Button(t("Отменить разметку", "Cancel mapping")) { model.navigate(.rules); model.learningStep = 0; model.learningSelections = [] }
            }
        }
    }
    private func learningField(_ key: String, _ title: String) -> some View {
        Toggle(title, isOn: Binding(get: { model.learningSelections.contains(key) }, set: {
            if $0 { model.learningSelections.insert(key) } else { model.learningSelections.remove(key) }
        })).tint(LabColor.accent)
    }
    private var compatibility: some View {
        Group {
            Section {
                input("Хосты провайдера входа", "Identity provider hosts", \.idpHosts)
                note("Пусто — доверять только цепочке переходов от шлюза.", "Leave empty to follow only the gateway’s redirect chain.")
                input("CSD Wrapper", "CSD Wrapper", \.csdWrapper)
                if model.draft?.options.embeddedCSD == true {
                    Text(t("Тестовый CSD-скрипт встроен", "Sample CSD script embedded"))
                    Button(t("Удалить скрипт", "Remove script"), role: .destructive) { model.draft?.options.embeddedCSD = false }
                } else {
                    Button(t("Встроить тестовый CSD-скрипт", "Embed sample CSD script")) { model.draft?.options.embeddedCSD = true }
                }
                note("Демо не читает файлы и не запускает скрипты. В рабочем приложении выбирается файл скрипта.", "This demo does not read files or execute scripts. Production opens a script file picker.")
            }
        }
    }
    private var profiles: some View {
        Group {
            Section {
                ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.profileTitle(profile)).lineLimit(1).help(model.profileTitle(profile))
                            Text(profile.server).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button("↑") { model.moveProfile(profile.id, by: -1) }.disabled(index == 0).help(t("Выше", "Move up"))
                        Button("↓") { model.moveProfile(profile.id, by: 1) }.disabled(index == model.profiles.count - 1).help(t("Ниже", "Move down"))
                        Button(t("Открыть", "Open")) {
                            model.requestSelection(profile.id); model.page = .connection; model.detail = nil
                        }
                    }
                }
                Button(t("Новый профиль", "New profile")) { model.add(); model.detail = nil }.disabled(model.dirty)
                note("Порядок профилей используется и в меню приложения.", "The application menu uses this profile order too.")
            }
            Section { DetailLink(model: model, destination: .transfer) }
            if model.legacyAvailable {
                Section(t("Старый формат · пример", "Legacy format · sample")) {
                    Text("legacy.example.com")
                    Button(t("Преобразовать в .ocmac", "Convert to .ocmac")) { model.convertLegacySample() }.disabled(model.dirty)
                }
            }
        }
    }
    private var transfer: some View {
        Group {
            Section(t("Профиль от коллеги", "A profile from a colleague")) {
                Text("branch.example.com.ocmac").font(.system(size: 13, weight: .medium))
                Text("https://branch.example.com").font(.system(size: 12)).foregroundStyle(.secondary)
                note("В файле есть команды или скрипты. Подключайтесь, только если доверяете отправителю.", "This file contains commands or scripts. Connect only if you trust the sender.")
                Toggle(t("Доверяю источнику тестового файла", "I trust the sample file’s source"), isOn: $model.importTrusted).tint(LabColor.accent)
                Button(t("Импортировать тестовый профиль", "Import sample profile")) { model.importSample() }.disabled(!model.importTrusted || model.dirty)
                note("Тестовый предпросмотр импорта .ocmac. Рабочий клиент также открывает файл двойным щелчком в Finder.", "Sample .ocmac import preview. Production also opens profiles from Finder.")
            }
            Section(t("Поделиться профилем", "Share a profile")) {
                Button(t("Предпросмотр экспорта", "Preview export")) { model.navigate(.filePreview) }.disabled(model.draft == nil)
                note("Пароли и секреты TOTP в файл не входят. Перед передачей проверьте команды, пути и адреса.", "Passwords and TOTP secrets are excluded. Review commands, paths and addresses before sharing.")
            }
        }
    }
    private var setup: some View {
        Group {
            Section {
                Picker(t("Шаг", "Step"), selection: $model.setupStep) {
                    Text(t("1. Система", "1. System")).tag(0)
                    Text(t("2. Профиль", "2. Profile")).tag(1)
                    Text(t("3. Вход", "3. Sign-in")).tag(2)
                }.pickerStyle(.segmented)
            }
            if model.setupStep == 0 {
                Section {
                    IconLabel(title: model.helperReady ? t("Помощник установлен", "Helper installed") : t("Нужен системный помощник", "System helper required"), icon: model.helperReady ? "circle-check" : "triangle-alert")
                        .foregroundStyle(model.helperReady ? LabColor.success : LabColor.warning)
                    Text("ocmac prepare && sudo ocmac install").font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    note("Команда выполняется в Терминале. Для режима SOCKS помощник не нужен. В демо проверка имитируется.", "Run the command in Terminal. SOCKS mode needs no helper. This demo simulates the check.")
                    Button(t("Повторить тестовую проверку", "Repeat sample check")) { model.helperReady = true }
                    Button(t("Далее", "Continue")) { model.setupStep = 1 }.disabled(!model.helperReady && model.draft?.route != .proxy)
                }
            } else if model.setupStep == 1 {
                Section {
                    Text(model.draft?.displayName ?? t("Профиль не выбран", "No profile selected"))
                    DetailLink(model: model, destination: .transfer)
                    Button(t("Настроить вручную", "Configure manually")) { if model.draft == nil { model.add() }; model.page = .connection; model.detail = nil }
                    Button(t("Ко входу", "Continue to sign-in")) { model.setupStep = 2 }.disabled(!model.valid)
                }
            } else {
                Section {
                    Button(t("Открыть вход", "Open sign-in")) { model.beginSignIn() }.disabled(!model.canStartConnection)
                    SingleLineInput(text: $model.setupResource, label: t("Рабочий ресурс", "Work resource"), placeholder: "https://intranet.example.com").frame(height: 26)
                    Button(t("Проверить тестовый доступ", "Check sample access")) { model.accessChecked = true }.disabled(model.activeID != model.selectedID || model.setupResource.isEmpty)
                    if model.accessChecked { Text(t("Тестовый ресурс доступен", "Sample resource is reachable")).foregroundStyle(LabColor.success) }
                    note("Соединение со шлюзом ещё не гарантирует доступ к рабочему ресурсу.", "A gateway connection does not guarantee access to work resources.")
                }
            }
        }
    }
    private var notifications: some View {
        Group {
            if !model.notificationsAllowed {
                Section {
                    IconLabel(title: t("macOS запрещает уведомления", "macOS notifications are blocked"), icon: "triangle-alert").foregroundStyle(LabColor.warning)
                    Button(t("Показать разрешённое состояние", "Show allowed state")) { model.notificationsAllowed = true }
                }
            }
            Section(t("Показывать", "Show notifications")) {
                Toggle(t("Нужен вход", "Sign-in required"), isOn: $model.notifyLogin).tint(LabColor.accent)
                Toggle(t("Проблемы со связью и доступом", "Connection and access problems"), isOn: $model.notifyProblems).tint(LabColor.accent)
                Toggle(t("Восстановление соединения", "Connection restored"), isOn: $model.notifyEvents).tint(LabColor.accent)
                note("Повтор одного события — не чаще раза в 10 минут. Стиль и звук задаются в macOS.", "Repeated events are limited to once per 10 minutes. macOS controls style and sound.")
            }
            Section {
                Button(t("Проверить уведомление", "Test notification")) {
                    model.notice = model.notificationsAllowed ? t("Пример: Нужен вход — сессия истекла, войдите снова.", "Preview: Sign-in required — your session expired. Sign in again.") : t("Уведомление заблокировано настройками macOS.", "Notification blocked by macOS settings.")
                }
                note("Демо показывает уведомление внутри окна. Настройки macOS не меняются.", "This demo previews notifications in the window. macOS settings stay unchanged.")
            }
        }
    }
    private var diagnostics: some View {
        Group {
            Section {
                diagnosticRow(t("Системный помощник", "System helper"), ok: model.helperReady)
                diagnosticRow(t("Супервизор", "Supervisor"), ok: true)
                diagnosticRow(t("Доступ к рабочему ресурсу", "Work resource access"), ok: !model.diagnosticsIssue)
                note("Тестовый результат ocmac doctor. Проверка ничего не меняет в системе.", "Sample ocmac doctor result. Diagnostics do not change system settings.")
                Button(t("Повторить проверку", "Check again")) { model.notice = t("Тестовая проверка завершена.", "Sample check completed.") }
                DetailLink(model: model, destination: .logs)
                DetailLink(model: model, destination: .report)
            }
            Section(t("Следы прошлой сессии", "Previous session leftovers")) {
                note("Убираются только наши неактивные маршруты, DNS и SOCKS. Живой туннель и чужие процессы не затрагиваются.", "Cleanup removes only our inactive routes, DNS and SOCKS. Live tunnels and other processes are preserved.")
                Button(t("Имитировать уборку", "Simulate cleanup")) { model.diagnosticsIssue = false; model.notice = t("Тестовые остаточные настройки убраны.", "Sample stale settings removed.") }
            }
        }
    }
    private func diagnosticRow(_ title: String, ok: Bool) -> some View {
        HStack { Text(title); Spacer(); Lucide(name: ok ? "circle-check" : "triangle-alert").foregroundStyle(ok ? LabColor.success : LabColor.warning) }
    }
    private var logs: some View {
        Group {
            Section {
                Picker(t("Источник", "Source"), selection: $model.logSource) {
                    Text(t("Супервизор", "Supervisor")).tag("supervisor")
                    Text("OpenConnect").tag("openconnect")
                    Text(t("Приложение", "Application")).tag("app")
                }
                SingleLineInput(text: $model.logFilter, label: t("Поиск в журнале", "Search logs"), placeholder: t("Фильтр…", "Filter…")).frame(height: 26)
                Toggle(t("Следить за новыми строками", "Follow new lines"), isOn: $model.followLog).tint(LabColor.accent)
            }
            Section {
                Text(model.logLines.isEmpty ? t("Совпадений нет", "No matches") : model.logLines.joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                note("\(model.logLines.count) строк · тестовый журнал", "\(model.logLines.count) lines · sample log")
            }
        }
    }
    private var runtime: some View {
        Group {
            if model.activeID != model.selectedID {
                Section { note("Сначала подключите выбранный профиль.", "Connect the selected profile first.") }
            } else if model.activeProfile?.route == .proxy {
                Section { Text("SOCKS5 · 127.0.0.1:\(model.activeProfile?.port ?? "11080")").textSelection(.enabled) }
            } else {
                Section {
                    Text(model.pausedID == model.selectedID ? t("Пауза: сети и DNS сняты, сессия жива", "Paused: routes and DNS removed; session alive") : t("Туннель работает", "Tunnel is running"))
                    Button(model.pausedID == model.selectedID ? t("Возобновить", "Resume") : t("Приостановить", "Pause")) { model.togglePause() }
                }
                Section(t("Сети в туннеле", "Tunnel routes")) {
                    ForEach(model.runtimeRoutes, id: \.self) { route in
                        Toggle(route, isOn: runtimeBinding(route, routes: true)).disabled(model.pausedID == model.selectedID).tint(LabColor.accent)
                    }
                }
                Section(t("DNS-зоны", "DNS zones")) {
                    ForEach(model.activeProfile?.zones ?? []) { zone in
                        Toggle("\(zone.zone) → \(zone.resolver)", isOn: runtimeBinding(zone.zone, routes: false)).disabled(model.pausedID == model.selectedID).tint(LabColor.accent)
                    }
                }
                note("Переключатели меняют текущую сессию. Сохранённый профиль остаётся прежним.", "These switches affect the current session. The saved profile stays unchanged.")
            }
        }
    }
    private func saveSample(_ content: String, name: String) {
        let panel = NSSavePanel()
        panel.title = t("Сохранить тестовый файл", "Save sample file")
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            model.notice = t("Тестовый файл сохранён.", "Sample file saved.")
        } catch { model.notice = t("Не удалось сохранить файл.", "Could not save the file.") }
    }
    private func runtimeBinding(_ key: String, routes: Bool) -> Binding<Bool> {
        Binding(get: { model.pausedID != model.selectedID && !(routes ? model.disabledRoutes : model.disabledZones).contains(key) }, set: { on in
            if routes { if on { model.disabledRoutes.remove(key) } else { model.disabledRoutes.insert(key) } }
            else { if on { model.disabledZones.remove(key) } else { model.disabledZones.insert(key) } }
        })
    }
}

struct DetailLink: View {
    @ObservedObject var model: DemoModel
    let destination: Detail
    var body: some View {
        Button { model.navigate(destination) } label: {
            HStack {
                Text(destination.title(model.language)).foregroundStyle(.primary)
                Spacer()
                Lucide(name: "arrow-right", size: 14).foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.vertical, 4)
    }
}
