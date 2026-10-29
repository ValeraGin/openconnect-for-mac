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
                    if model.page != .general { profilePicker; Divider() }
                    heading
                    if model.page == .general { general }
                    else if model.draft == nil { empty }
                    else {
                        Form {
                            switch model.page {
                            case .connection: connection
                            case .login: login
                            case .network: network
                            case .advanced: advanced
                            case .general: EmptyView()
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
            ForEach(Page.allCases.filter { $0 != .general }, id: \.self) { item in nav(item) }
            Divider().padding(.horizontal, 12).padding(.vertical, 14)
            nav(.general)
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
        Button { model.page = page } label: {
            IconLabel(title: model.title(page), icon: page.icon)
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
                            Text(profile.displayName
                                 + (model.activeID == profile.id ? text(" • подключён", " • connected") : ""))
                                .tag(profile.id)
                        }
                    }
                    .labelsHidden().accessibilityLabel(text("Профиль", "Profile"))
                    .frame(maxWidth: .infinity).help(model.draft?.displayName ?? "")
            }
            Button { model.add() } label: { Lucide(name: "plus", size: 16) }
                .disabled(model.dirty)
                .help(text("Добавить профиль", "Add profile"))
                .accessibilityLabel(text("Добавить профиль", "Add profile"))
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title(model.page)).font(.system(size: 20, weight: .semibold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
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
        }
    }
    private var empty: some View {
        VStack(spacing: 12) {
            Lucide(name: "shield", size: 40).foregroundStyle(LabColor.accent)
            Text(text("Добавьте первый профиль", "Add your first profile")).font(.headline)
            Text(text("Нужны адрес VPN и имя пользователя.", "You’ll need a VPN address and a username."))
                .foregroundStyle(.secondary)
            Button(text("Добавить профиль", "Add profile")) { model.add() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var connection: some View {
        Group {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    if model.selectedLink == .connecting {
                        ProgressView().controlSize(.small).frame(width: 28)
                    } else {
                        Lucide(name: statusIcon, size: 24).foregroundStyle(statusColor)
                            .frame(width: 40, height: 40)
                            .background(statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle).fontWeight(.semibold).foregroundStyle(statusColor)
                        Text(statusDetail).font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button(connectionAction) { model.toggleConnection() }
                        .buttonStyle(.borderedProminent).tint(LabColor.accent)
                        .disabled(model.dirty || !model.valid)
                }.padding(.vertical, 5)
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
            Text(label).font(.system(size: 12)).frame(width: 88, alignment: .leading)
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
        if model.activeID == model.selectedID { return LabColor.success }
        if model.selectedLink == .failed { return LabColor.failure }
        if !model.valid { return LabColor.warning }
        if model.selectedLink == .connecting || model.selectedLink == .signIn { return LabColor.accent }
        return .secondary
    }
    private var statusTitle: String {
        if model.activeID == model.selectedID { return text("Подключено", "Connected") }
        if model.selectedLink == .connecting { return text("Подключаемся…", "Connecting…") }
        if model.selectedLink == .signIn { return text("Ожидается вход", "Sign-in required") }
        if model.selectedLink == .failed { return text("Не удалось подключиться", "Couldn’t connect") }
        if !model.valid { return text("Заполните профиль", "Complete the profile") }
        return text("Не подключено", "Disconnected")
    }
    private var statusDetail: String {
        if model.activeID == model.selectedID { return text("Соединение установлено · 12 мин", "Connection established · 12 min") }
        if model.selectedLink == .connecting { return text("Ожидаем ответ сервера", "Waiting for the server") }
        if model.selectedLink == .signIn { return text("Завершите вход в открытом окне", "Complete sign-in in the open window") }
        if model.selectedLink == .failed { return text("Сервер не отвечает", "The server is not responding") }
        if !model.valid { return text("Для подключения нужны корректные параметры", "Valid settings are required to connect") }
        return text("Готово к подключению", "Ready to connect")
    }
    private var statusIcon: String {
        if model.activeID == model.selectedID { return "shield-check" }
        if model.selectedLink == .failed { return "triangle-alert" }
        return model.selectedLink == .signIn ? "log-in" : "network"
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
                        .buttonStyle(.borderedProminent).tint(LabColor.accent).disabled(model.dirty || !model.valid)
                }
                Text(model.dirty
                     ? text("Сначала сохраните изменения профиля.", "Save profile changes first.")
                     : text("Вход → одноразовый код → подключение. Пароль demo, код 287082.", "Sign-in → one-time code → connection. Password demo, code 287082."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Section(text("Сохранённые данные", "Saved credentials")) {
                credential(text("Пароль", "Password"), key: \.passwordSaved, stage: .credentialPassword)
                if model.draft?.browserLogin == true {
                    credential(text("TOTP", "TOTP"), key: \.codeSaved, stage: .credentialCode)
                } else {
                    Text(text("Код из SMS вводится при каждом входе. Сохранить его для будущих входов нельзя.", "Enter the SMS code each time. It cannot be saved for future sign-ins."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Text(text("Изменение пароля и кода открывается в отдельном окне. Используйте только тестовые данные.", "Passwords and codes are edited in a separate window. Use sample data only."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
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
                    profileField(text("Домены DNS", "DNS domains"), key: \.dns)
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
            Section(text("Совместимость", "Compatibility")) {
                profileField(text("Прокси входа", "Upstream proxy"), key: \.upstreamProxy)
                profileField("User-Agent", key: \.userAgent)
                Text(text("Прокси: HTTP CONNECT или SOCKS5 без пароля. Пусто — прямое подключение.", "Proxy: HTTP CONNECT or SOCKS5 without authentication. Blank means a direct connection."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
    private var general: some View {
        Form {
            Section {
                Toggle(text("Запускать при входе в macOS", "Launch when signing in to macOS"), isOn: $model.launchAtLogin).tint(LabColor.accent)
                Picker(text("Язык", "Language"), selection: $model.language) {
                    Text("Русский").tag(Language.ru)
                    Text("English").tag(Language.en)
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
                Toggle(text("Не подключаться в этой сети", "Don’t connect on this network"), isOn: $model.skipNetwork)
                Text(text("Профили с паролем и SMS требуют ручного входа.", "Password + SMS profiles require manual sign-in."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text(text("В демо настройки не меняют автозапуск и рабочее приложение.", "Demo settings do not change system login items or the installed VPN app."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
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
