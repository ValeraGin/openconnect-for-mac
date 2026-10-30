import SwiftUI

struct LabView: View {
    @ObservedObject var model: DemoModel
    @State private var showReset = false

    private func field<T>(_ key: WritableKeyPath<DemoProfile, T>, fallback: T) -> Binding<T> {
        Binding(get: { model.draft?[keyPath: key] ?? fallback }, set: { model.draft?[keyPath: key] = $0 })
    }
    private func text(_ ru: String, _ en: String) -> String { model.t(ru, en) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                VStack(spacing: 0) {
                    if !model.page.isGlobal { profilePicker; Divider() }
                    heading
                    if model.detail != nil {
                        CapabilitiesView(model: model)
                        if !model.page.isGlobal { footer }
                    }
                    else if [.notifications, .diagnostics].contains(model.page) { CapabilitiesView(model: model) }
                    else if model.page == .general { general }
                    else if model.draft == nil { empty }
                    else {
                        Form {
                            switch model.page {
                            case .connection: connection
                            case .login: login
                            case .network: network
                            case .advanced: advanced
                            case .general, .notifications, .diagnostics: EmptyView()
                            }
                        }
                        .formStyle(.grouped)
                        .scrollContentBackground(.hidden)
                        footer
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            Divider()
            testControls
        }
        .frame(width: 680, height: 620)
        .alert(text("Сохранить изменения?", "Save changes?"), isPresented: $model.showUnsaved) {
            Button(text("Сохранить", "Save")) { _ = model.save() }
            Button(text("Не сохранять", "Discard"), role: .destructive) { model.discardAndSelect() }
            Button(text("Отмена", "Cancel"), role: .cancel) { model.pendingSelection = nil }
        } message: {
            Text(text("В текущем профиле есть несохранённые изменения.", "The current profile has unsaved changes."))
        }
        .alert(text("Профиль изменён снаружи", "Profile changed outside the editor"), isPresented: $model.confirmOverwrite) {
            Button(text("Перечитать", "Reload")) { model.resolveConflict(reload: true) }
            Button(text("Перезаписать", "Overwrite"), role: .destructive) { model.resolveConflict(reload: false) }
            Button(text("Отмена", "Cancel"), role: .cancel) { }
        } message: { Text(text("Выберите, какие правки оставить. В рабочем приложении предыдущий файл сохраняется как .bak.", "Choose which edits to keep. Production preserves the previous file as .bak.")) }
        .alert(text("Сбросить демо?", "Reset demo?"), isPresented: $showReset) {
            Button(text("Сбросить", "Reset")) { model.load(model.scenario) }
            Button(text("Отмена", "Cancel"), role: .cancel) { }
        } message: { Text(text("Изменения тестовых данных будут потеряны.", "Your demo data edits will be discarded.")) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text("ПРОФИЛЬ", "PROFILE"))
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
            ForEach(Page.allCases.filter { !$0.isGlobal }, id: \.self) { item in nav(item) }
            Divider().padding(.horizontal, 12).padding(.vertical, 14)
            ForEach(Page.allCases.filter { $0.isGlobal }, id: \.self) { item in nav(item) }
            Button { model.aboutPresented = true } label: {
                IconLabel(title: text("О приложении", "About"), icon: "info")
                    .font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9).padding(.vertical, 9)
            }.buttonStyle(.plain).padding(.horizontal, 8)
            Spacer()
            Text(text("Новый интерфейс\nТестовые данные", "New interface\nSample data"))
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(16)
        }
        .frame(width: 166)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    private func nav(_ page: Page) -> some View {
        Button { model.page = page; model.detail = nil; model.notice = "" } label: {
            HStack(spacing: 8) {
                if page == .connection { BrandMark(size: 18) } else { Lucide(name: page.icon) }
                Text(model.title(page))
            }
                .font(.system(size: 12, weight: model.page == page ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9).padding(.vertical, 9)
                .foregroundStyle(model.page == page ? LabColor.accent : .primary)
                .background(model.page == page ? LabColor.accent.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 8)
        .accessibilityAddTraits(model.page == page ? .isSelected : [])
    }
    private var profilePicker: some View {
        HStack(spacing: 10) {
            if model.profiles.isEmpty {
                Text(text("Профили", "Profiles")).foregroundStyle(.secondary)
                Spacer()
            } else {
                Picker(text("Профиль", "Profile"), selection: Binding(
                    get: { model.selectedID ?? "" }, set: { model.requestSelection($0) })) {
                        ForEach(model.profiles) { profile in
                            Text(model.profileMenuTitle(profile))
                                .tag(profile.id)
                        }
                    }
                    .labelsHidden().accessibilityLabel(text("Профиль", "Profile"))
                    .frame(maxWidth: .infinity).help(model.draft?.displayName ?? "")
            }
            Menu {
                Button(text("Управление профилями…", "Manage profiles…")) { model.navigate(.profiles) }
                Button(text("Импорт и экспорт…", "Import and export…")) { model.navigate(.transfer) }
                Button(text("Предпросмотр файла…", "Preview file…")) { model.navigate(.filePreview) }.disabled(model.draft == nil)
            } label: { Lucide(name: "ellipsis", size: 16) }.fixedSize()
                .help(text("Действия с профилями", "Profile actions"))
            Button { model.add(); model.detail = nil } label: { Lucide(name: "plus", size: 16) }
                .disabled(model.dirty)
                .help(text("Добавить профиль", "Add profile"))
                .accessibilityLabel(text("Добавить профиль", "Add profile"))
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.detail != nil {
                Button("← " + model.title(model.page)) { model.detail = nil; model.notice = "" }.buttonStyle(.link).padding(.bottom, 4)
            }
            Text(model.detail?.title(model.language) ?? model.title(model.page)).font(.system(size: 20, weight: .semibold))
            Text(model.detail == nil ? subtitle : text("Параметры и действия · тестовые данные", "Options and actions · sample data")).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 2)
    }
    private var subtitle: String {
        switch model.page {
        case .connection: return text("Сервер и состояние выбранного профиля.", "Server and status of the selected profile.")
        case .login: return text("Как подтверждать вход в VPN.", "How to sign in to your VPN.")
        case .network: return text("Какой трафик направлять через VPN.", "Choose which traffic uses the VPN.")
        case .advanced: return text("Необязательные параметры этого профиля.", "Optional settings for this profile.")
        case .general: return text("Настройки для всех профилей.", "Settings shared by all profiles.")
        case .notifications: return text("Какие события показывать.", "Choose which events to show.")
        case .diagnostics: return text("Проверка доступа и журналы.", "Access checks and logs.")
        }
    }
    private var empty: some View {
        VStack(spacing: 12) {
            Lucide(name: "folder-plus", size: 32).foregroundStyle(LabColor.accent)
                .frame(width: 58, height: 58).background(LabColor.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            Text(text("Добавьте первый профиль", "Add your first profile")).font(.headline)
            Text(text("Нужны адрес VPN и имя пользователя.", "You’ll need a VPN address and a username."))
                .foregroundStyle(.secondary)
            Button(text("Добавить профиль", "Add profile")) { model.add() }
            Button(text("Открыть профиль от коллеги…", "Open a shared profile…")) { model.navigate(.transfer) }.buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var connection: some View {
        Group {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    BrandMark(size: 40)
                        .overlay(alignment: .bottomTrailing) {
                            if model.selectedLink == .connecting { ProgressView().controlSize(.mini) }
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle).fontWeight(.semibold).foregroundStyle(statusColor)
                        Text(statusDetail).font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button(connectionAction) { model.toggleConnection() }
                        .buttonStyle(.borderedProminent).tint(LabColor.accent)
                        .disabled(model.activeID != model.selectedID && !model.canStartConnection)
                }.padding(.vertical, 5)
                if !model.helperReady && model.draft?.route != .proxy {
                    Text(text("Для туннеля нужен системный помощник.", "Tunnel mode needs the system helper.")).font(.system(size: 12)).foregroundStyle(LabColor.warning)
                    DetailLink(model: model, destination: .setup)
                }
                if model.scenario == .proxyWarning && model.activeID == model.selectedID {
                    IconLabel(title: text("Системный SOCKS не включён. Порт 11080 занят.", "System SOCKS is off. Port 11080 is already in use."), icon: "triangle-alert")
                        .foregroundStyle(LabColor.warning)
                        .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    Button(text("Открыть настройки сети", "Open network settings")) { model.page = .network }
                        .buttonStyle(.link)
                }
                if model.selectedLink == .failed {
                    DisclosureGroup(text("Подробности ошибки", "Error details"), isExpanded: $model.showDetails) {
                        Text(text("Сервер vpn.example.com не ответил за 30 секунд. Проверьте адрес и доступ к интернету, затем повторите подключение.\n\nTLS handshake timed out (ETIMEDOUT).", "vpn.example.com did not respond within 30 seconds. Check the address and your internet connection, then try again.\n\nTLS handshake timed out (ETIMEDOUT)."))
                            .font(.system(size: 12)).textSelection(.enabled)
                    }
                }
            }
            if model.activeID == model.selectedID {
                Section {
                    if model.activeProfile?.route != .proxy {
                        Button(model.pausedID == model.selectedID ? text("Возобновить", "Resume") : text("Приостановить", "Pause")) { model.togglePause() }
                    }
                    DetailLink(model: model, destination: .runtime)
                }
            }
            Section(text("Параметры профиля", "Profile details")) {
                profileField(text("Адрес VPN", "VPN address"), key: \.server)
                profileField(text("Пользователь", "Username"), key: \.user)
            }
            if model.activeID != nil && model.activeID != model.selectedID {
                Text(text("Сейчас подключён другой профиль. Подключение переключится на выбранный.", "Another profile is connected. Connecting will switch to this profile."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
    private func profileField(_ label: String, key: WritableKeyPath<DemoProfile, String>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label).font(.system(size: 12)).frame(width: 104, alignment: .leading)
            SingleLineInput(text: field(key, fallback: ""), label: label).frame(height: 26)
        }.frame(maxWidth: .infinity)
    }
    private var routesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text("Подсети", "Subnets")).font(.system(size: 12))
            TextEditor(text: field(\.routes, fallback: ""))
                .font(.system(size: 12, design: .monospaced)).scrollContentBackground(.hidden)
                .frame(height: 66).padding(4)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.16)))
                .accessibilityLabel(text("Подсети, по одной на строку", "Subnets, one per line"))
        }
    }
    private var statusColor: Color {
        if model.pausedID == model.selectedID && model.selectedID != nil { return LabColor.warning }
        if model.activeID == model.selectedID { return LabColor.success }
        if model.selectedLink == .failed { return LabColor.failure }
        if !model.helperReady && model.draft?.route != .proxy { return LabColor.warning }
        if !model.valid || model.dirty || model.conflict { return LabColor.warning }
        if model.selectedLink == .connecting || model.selectedLink == .signIn { return LabColor.accent }
        return .secondary
    }
    private var statusTitle: String {
        if model.pausedID == model.selectedID && model.selectedID != nil { return text("Приостановлено", "Paused") }
        if model.activeID == model.selectedID { return text("Подключено", "Connected") }
        if model.selectedLink == .connecting { return text("Подключаемся…", "Connecting…") }
        if model.selectedLink == .signIn { return text("Ожидается вход", "Sign-in required") }
        if model.selectedLink == .failed { return text("Не удалось подключиться", "Couldn’t connect") }
        if !model.helperReady && model.draft?.route != .proxy { return text("Нужна настройка", "Setup required") }
        if !model.valid { return text("Заполните профиль", "Complete the profile") }
        return text("Не подключено", "Disconnected")
    }
    private var statusDetail: String {
        if model.pausedID == model.selectedID && model.selectedID != nil { return text("Сети и DNS сняты, сессия жива", "Routes and DNS removed; session alive") }
        if model.activeID == model.selectedID { return text("Соединение установлено · 12 мин", "Connection established · 12 min") }
        if model.selectedLink == .connecting { return text("Ожидаем ответ сервера", "Waiting for the server") }
        if model.selectedLink == .signIn { return text("Завершите вход в открытом окне", "Complete sign-in in the open window") }
        if model.selectedLink == .failed { return text("Сервер не отвечает", "The server is not responding") }
        if !model.helperReady && model.draft?.route != .proxy { return text("Откройте мастер настройки", "Open the setup assistant") }
        if !model.valid { return text("Для подключения нужны корректные параметры", "Valid settings are required to connect") }
        if model.conflict { return text("Разрешите конфликт изменений", "Resolve the file conflict first") }
        if model.dirty { return text("Сначала сохраните изменения", "Save changes before connecting") }
        return text("Готово к подключению", "Ready to connect")
    }
    private var connectionAction: String {
        if model.activeID == model.selectedID { return text("Отключить", "Disconnect") }
        if model.selectedLink == .connecting { return text("Отменить", "Cancel") }
        if model.selectedLink == .signIn { return text("Войти", "Sign in") }
        if model.selectedLink == .failed { return text("Повторить", "Retry") }
        return text("Подключить", "Connect")
    }
    private var login: some View {
        Group {
            Section {
                Picker(text("Способ входа", "Sign-in method"), selection: field(\.browserLogin, fallback: true)) {
                    Text(text("В браузере (SSO)", "Browser (SSO)")).tag(true)
                    Text(text("Пароль и SMS", "Password and SMS")).tag(false)
                }
                Text(model.draft?.browserLogin == true
                     ? text("При подключении откроется страница входа организации.", "Your organization’s sign-in page opens when connecting.")
                     : text("Пароль используется для входа на сервер VPN.", "Your password is used to sign in to the VPN server."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Section(text("Окно входа", "Sign-in window")) {
                HStack {
                    IconLabel(title: text("Проверить вход в профиль", "Try signing in to this profile"), icon: "log-in")
                        .font(.system(size: 12)).foregroundStyle(LabColor.accent)
                    Spacer(minLength: 8)
                    Button(text("Открыть", "Open")) { model.beginSignIn() }
                        .buttonStyle(.borderedProminent).tint(LabColor.accent).disabled(!model.canStartConnection)
                }
                Text(model.dirty
                     ? text("Сначала сохраните изменения профиля.", "Save profile changes first.")
                     : text("Вход → одноразовый код → подключение. Пароль demo, код \(model.selectedDemoCode).", "Sign-in → one-time code → connection. Password demo, code \(model.selectedDemoCode)."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Section(text("Сохранённые данные", "Saved credentials")) {
                if ["auto", "keychain"].contains(model.draft?.options.passwordSource ?? "auto") {
                    credential(text("Пароль", "Password"), key: \.passwordSaved, stage: .credentialPassword)
                } else { LabeledContent(text("Источник пароля", "Password source"), value: model.sourceTitle(model.draft?.options.passwordSource ?? "auto")) }
                if model.draft?.browserLogin == true {
                    if ["auto", "keychain"].contains(model.draft?.options.codeSource ?? "auto") {
                        credential("TOTP", key: \.codeSaved, stage: .credentialCode)
                        if model.draft?.codeSaved == true {
                            HStack {
                                Text(model.selectedDemoCode).font(.system(size: 17, weight: .medium, design: .monospaced))
                                Text(text("Тестовый код · \(model.draft?.options.period ?? "30") с", "Sample code · \(model.draft?.options.period ?? "30") s")).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        DetailLink(model: model, destination: .qrImport)
                    } else { LabeledContent(text("Источник кода", "Code source"), value: model.sourceTitle(model.draft?.options.codeSource ?? "auto")) }
                } else {
                    Text(text("Код из SMS вводится при каждом входе. Сохранить его для будущих входов нельзя.", "Enter the SMS code each time. It cannot be saved for future sign-ins."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Section {
                DetailLink(model: model, destination: .sources)
                if model.draft?.browserLogin == true { DetailLink(model: model, destination: .rules) }
            }
        }
    }
    private func credential(_ label: String, key: WritableKeyPath<DemoProfile, Bool>, stage: AuthStage) -> some View {
        LabeledContent(label) {
            HStack {
                Text(model.draft?[keyPath: key] == true ? text("Сохранён", "Saved") : text("Не сохранён", "Not saved"))
                    .foregroundStyle(model.draft?[keyPath: key] == true ? LabColor.success : .secondary)
                Button(model.draft?[keyPath: key] == true ? text("Изменить…", "Edit…") : text("Добавить…", "Add…")) {
                    model.openCredential(stage)
                }.disabled(model.dirty || !model.valid)
            }
        }
    }
    private var network: some View {
        Group {
            Section {
                Picker(text("Через VPN", "Use VPN for"), selection: field(\.route, fallback: .selected)) {
                    Text(text("Весь IPv4-трафик", "All IPv4 traffic")).tag(RouteMode.all)
                    Text(text("Выбранные сети", "Selected networks")).tag(RouteMode.selected)
                    Text(text("Только SOCKS-прокси", "SOCKS proxy only")).tag(RouteMode.proxy)
                }.pickerStyle(.radioGroup)
            }
            if model.draft?.route == .selected {
                Section(text("Выбранные сети", "Selected networks")) {
                    routesField
                    DetailLink(model: model, destination: .dns)
                }
                Text(text("Остальной трафик идёт напрямую. По одной подсети на строку.", "Other traffic connects directly. Enter one subnet per line."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else if model.draft?.route == .proxy {
                Section(text("SOCKS-прокси", "SOCKS proxy")) {
                    profileField(text("Порт", "Port"), key: \.port)
                    Toggle(text("Использовать в настройках macOS", "Use in macOS network settings"), isOn: field(\.systemProxy, fallback: false)).tint(LabColor.accent)
                }
                Text(text("VPN доступен приложениям, настроенным на этот прокси.", "VPN is available to apps configured to use this proxy."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                DetailLink(model: model, destination: .dns)
                Text(text("Весь IPv4-трафик идёт через туннель (0.0.0.0/1 и 128.0.0.0/1).", "All IPv4 traffic uses the tunnel (0.0.0.0/1 and 128.0.0.0/1)."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
    private var advanced: some View {
        Group {
            Section(text("Профиль", "Profile")) {
                profileField(text("Своё имя", "Custom name"), key: \.name)
                Text(text("Необязательно. Без имени используется адрес VPN.", "Optional. The VPN address is used when this is blank."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Section(text("Параметры", "Options")) {
                optionField(text("Описание", "Description"), key: \.description)
                optionField(text("Доступ", "Access check"), key: \.health)
                Toggle(text("Уведомления этого профиля", "Profile notifications"), isOn: Binding(get: { model.draft?.options.notifications ?? true }, set: { model.draft?.options.notifications = $0 })).tint(LabColor.accent)
            }
            Section(text("Совместимость", "Compatibility")) {
                profileField(text("Прокси входа", "Upstream proxy"), key: \.upstreamProxy)
                profileField("User-Agent", key: \.userAgent)
                HStack {
                    Text(text("Известные клиенты", "Known clients"))
                    Spacer()
                    Menu(text("Выбрать…", "Choose…")) {
                    ForEach(["AnyConnect Windows 4.10.06079", "AnyConnect Darwin_i386 4.10.06079", "AnyConnect Linux_64 4.10.06079"], id: \.self) { value in
                        Button(value) { model.draft?.userAgent = value }
                    }
                    }.fixedSize()
                }
                DetailLink(model: model, destination: .compatibility)
                DetailLink(model: model, destination: .filePreview)
                Text(text("Прокси: HTTP CONNECT или SOCKS5 без пароля. Пусто — прямое подключение.", "Proxy: HTTP CONNECT or SOCKS5 without authentication. Blank means a direct connection."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
    private func optionField(_ label: String, key: WritableKeyPath<DemoOptions, String>) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 12)).frame(width: 104, alignment: .leading)
            SingleLineInput(text: Binding(get: { model.draft?.options[keyPath: key] ?? "" }, set: { model.draft?.options[keyPath: key] = $0 }), label: label).frame(height: 26)
        }
    }
    private var general: some View {
        Form {
            Section {
                Toggle(text("Запускать при входе в macOS", "Launch when signing in to macOS"), isOn: $model.launchAtLogin).tint(LabColor.accent)
                Picker(text("Язык", "Language"), selection: Binding(get: { model.appLanguage }, set: { value in
                    model.appLanguage = value
                    model.language = value == "system" ? (Locale.current.identifier.hasPrefix("ru") ? .ru : .en) : Language(rawValue: value) ?? .ru
                })) {
                    Text(text("Как в системе", "System")).tag("system")
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }

            }
            Section(text("Автоподключение", "Automatic connection")) {
                Picker(text("Поведение", "Policy"), selection: $model.autoPolicy) {
                    Text(text("Вручную", "Manual")).tag("manual")
                    Text(text("Восстанавливать прошлое", "Resume previous")).tag("resume")
                    ForEach(model.profiles.filter { $0.browserLogin }) { profile in
                        Text(text("Всегда: ", "Always: ") + profile.displayName).tag("always " + profile.id)
                    }
                }
                Toggle(text("Не подключаться в этой сети", "Don’t connect on this network"), isOn: $model.skipNetwork).tint(LabColor.accent)
                Text(text("Профили с паролем и SMS требуют ручного входа.", "Password + SMS profiles require manual sign-in."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Section {
                DetailLink(model: model, destination: .setup)
                DetailLink(model: model, destination: .profiles)
                Toggle(text("Режим разработчика", "Developer mode"), isOn: $model.developer).tint(LabColor.accent)
                if model.developer {
                    Button(text("Сбросить тестовый вход", "Reset sample sign-in")) { model.activeID = nil; model.pausedID = nil; model.link = .idle }
                }
            }
            Text(text("В демо настройки не меняют автозапуск и рабочее приложение.", "Demo settings do not change system login items or the installed VPN app."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            if model.conflict {
                Text(text("Файл изменён снаружи. При сохранении выберите, какие правки оставить.", "The file changed outside the editor. Choose which edits to keep when saving."))
                    .font(.system(size: 11)).foregroundStyle(LabColor.warning)
            }
            if model.showValidation && !model.valid {
                Text(validationMessage)
                    .font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack(spacing: 8) {
                Text(model.dirty ? text("Есть изменения", "Unsaved changes") : text("Изменений нет", "No changes"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button(text("Отменить", "Revert")) { model.select(model.selectedID) }.disabled(!model.dirty)
                Button(text("Сохранить", "Save")) { _ = model.save() }
                    .buttonStyle(.borderedProminent).tint(LabColor.accent).disabled(!model.dirty)
            }
        }.padding(.horizontal, 22).padding(.bottom, 16)
    }
    private var validationMessage: String {
        let raw = model.draft?.server ?? ""
        let url = URL(string: raw.contains("://") ? raw : "https://" + raw)
        if url?.scheme != "https" || url?.host?.isEmpty != false {
            return text("Укажите адрес VPN, например vpn.example.com/group.", "Enter a VPN address, such as vpn.example.com/group.")
        }
        if let issue = model.extendedIssues.first { return issue }
        return text("В разделе «Сеть» укажите порт от 1 до 65535.", "In Network, enter a port from 1 to 65535.")
    }
    private var testControls: some View {
        HStack(spacing: 12) {
            IconLabel(title: "Demo", icon: "flask-conical").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Menu {
                ForEach(Scenario.allCases, id: \.self) { scenario in
                    Button(model.title(scenario)) { model.load(scenario) }
                }
            } label: { Text(model.title(model.scenario)) }
                .frame(width: 175)
            Picker("Language", selection: $model.language) {
                Text("RU").tag(Language.ru); Text("EN").tag(Language.en)
            }.labelsHidden().frame(width: 60)
            Picker("Appearance", selection: $model.appearance) {
                Text(text("Авто", "Auto")).tag("system")
                Text(text("Светлое", "Light")).tag("light")
                Text(text("Тёмное", "Dark")).tag("dark")
            }.labelsHidden().frame(width: 90)
            Spacer(minLength: 0)
            Button { model.reopen() } label: { Lucide(name: "square-arrow-out-up-right", size: 14) }
                .disabled(model.dirty)
                .help(text("Открыть настройки заново: активный или последний профиль", "Reopen settings: active or last selected profile"))
            Button { showReset = true } label: { Lucide(name: "rotate-ccw", size: 14) }
                .help(text("Сбросить демо", "Reset demo"))
        }
        .controlSize(.small).padding(.horizontal, 14).padding(.vertical, 10)
    }
}
