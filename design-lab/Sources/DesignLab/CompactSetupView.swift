import SwiftUI
import Settings

struct CompactSetupView: View {
    @ObservedObject var model: DemoModel
    @ObservedObject var state: CompactSetupState
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 28)
                Text(t("Настройка подключения", "Set up connection")).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(stepTitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.vertical, 16)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                switch state.step {
                case .connection: connection
                case .signin: signIn
                case .network: network
                case .system: system
                case .verify: verification
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            HStack {
                if state.step != .connection { Button(t("Назад", "Back")) { state.back() } }
                else { Button(t("Пример профиля", "Sample profile")) { state.sample("filled") }.buttonStyle(.link) }
                Spacer()
                if state.step == .network {
                    Button(t("Не применять", "Skip")) { state.skipServerSettings() }
                }
                Button(primaryTitle) {
                    if state.step == .verify { state.reset() } else { state.next() }
                }.buttonStyle(.borderedProminent)
                    .disabled(state.step == .system && !state.helperReady)
            }.padding(.horizontal, 24).padding(.vertical, 12)
            Divider()
            HStack(spacing: 10) {
                Text(t("Демо · без VPN", "Demo · no VPN")).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Picker("Layout", selection: $state.layout) {
                    Text("SwiftUI + AppKit").tag(CompactLayout.native)
                    Text("Settings 3.0").tag(CompactLayout.library)
                }.labelsHidden().frame(width: 160)
                Picker("Language", selection: $model.language) {
                    Text("RU").tag(Language.ru); Text("EN").tag(Language.en)
                }.labelsHidden().frame(width: 58)
                Picker("Appearance", selection: $model.appearance) {
                    Text(t("Авто", "Auto")).tag("system"); Text(t("Светлая", "Light")).tag("light"); Text(t("Тёмная", "Dark")).tag("dark")
                }.labelsHidden().frame(width: 84)
                Button { state.reset() } label: { Lucide(name: "rotate-ccw", size: 13) }.help(t("Сбросить демо", "Reset demo"))
            }.controlSize(.small).padding(.horizontal, 16).padding(.vertical, 7)
        }
        .frame(width: 560, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $state.editor) { _ in CompactListEditor(model: model, state: state) }
    }
    private var primaryTitle: String {
        switch state.step {
        case .signin: return t("Имитировать успешный вход", "Simulate successful sign-in")
        case .network: return t("Применить выбранное", "Apply selected")
        case .verify: return t("Начать заново", "Start again")
        default: return t("Продолжить", "Continue")
        }
    }
    private var stepTitle: String {
        switch state.step {
        case .connection: return t("1 · Подключение", "1 · Connection")
        case .system: return t("2 · Система", "2 · System")
        case .signin: return t("Вход", "Sign-in")
        case .network: return t("После входа · Сеть", "After sign-in · Network")
        case .verify: return t("Проверка", "Verify")
        }
    }
    private var signIn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.address).lineLimit(1).truncationMode(.middle).help(state.address)
            IconLabel(title: t("Вход в VPN", "Sign in to VPN"), icon: "log-in")
            hint(t("Сначала войдите в VPN. Затем сервер сможет передать подсети и DNS для выбора.", "Sign in first. The server can then supply subnets and DNS for you to review."))
            hint(t("В этом демо вход и ответ сервера имитируются.", "Sign-in and the server response are simulated in this demo."))
        }.padding(24)
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.layout == .library {
                Settings.Container(contentWidth: 500) {
                    Settings.Section(title: t("Адрес VPN:", "VPN address:")) { address.frame(width: 350) }
                    Settings.Section(title: t("Пользователь:", "Username:")) { username.frame(width: 350) }
                    Settings.Section(title: t("Вход:", "Sign-in:")) { login.frame(width: 350) }
                    Settings.Section(title: t("Режим:", "Mode:")) { transport.frame(width: 350) }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                    GridRow { rowLabel(t("Адрес VPN", "VPN address")); address }
                    GridRow { rowLabel(t("Пользователь", "Username")); username }
                    GridRow { rowLabel(t("Вход", "Sign-in")); login }
                    GridRow { rowLabel(t("Режим", "Mode")); transport }
                }.padding(24)
            }
            if state.mode == .proxy {
                HStack {
                    Text(t("Порт SOCKS", "SOCKS port")).font(.system(size: 12))
                    SingleLineInput(text: $state.port, label: "SOCKS port").frame(width: 70, height: 24)
                    Toggle(t("Системный SOCKS", "System SOCKS"), isOn: $state.systemProxy)
                }.padding(.horizontal, 24)
            }
            Text(t("Адрес станет именем профиля. Пароль и код — при подключении.", "The address becomes the profile name. Enter your password and code when connecting."))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 24)
            if state.showError {
                Label(state.validAddress ? t("Укажите порт от 1 до 65535.", "Enter a port from 1 to 65535.") : t("Укажите адрес VPN с HTTPS.", "Enter an HTTPS VPN address."), systemImage: "exclamationmark.circle")
                    .font(.system(size: 12)).foregroundStyle(LabColor.failure).padding(.horizontal, 24)
            }
        }
    }
    private func rowLabel(_ text: String) -> some View { Text(text).font(.system(size: 12)).frame(width: 100, alignment: .leading) }
    private var address: some View { SingleLineInput(text: $state.address, label: t("Адрес VPN", "VPN address"), placeholder: "vpn.example.com/group").frame(height: 24) }
    private var username: some View { SingleLineInput(text: $state.user, label: t("Пользователь", "Username"), placeholder: t("Если требуется", "If required")).frame(height: 24) }
    private var login: some View {
        Picker(t("Вход", "Sign-in"), selection: $state.browserLogin) {
            Text(t("SSO в окне браузера", "SSO in a browser window")).tag(true)
            Text(t("Пароль и SMS", "Password and SMS")).tag(false)
        }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
    }
    private var transport: some View {
        Picker(t("Режим", "Mode"), selection: Binding(get: { state.mode == .proxy }, set: { state.mode = $0 ? .proxy : .selected })) {
            Text(t("VPN-туннель", "VPN tunnel")).tag(false)
            Text(t("SOCKS-прокси", "SOCKS proxy")).tag(true)
        }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
    }
    private var mode: some View {
        Picker(t("Трафик", "Traffic"), selection: $state.mode) {
            Text(t("Выбранные сети", "Selected networks")).tag(RouteMode.selected)
            Text(t("Весь IPv4-трафик", "All IPv4 traffic")).tag(RouteMode.all)
        }.labelsHidden()
    }
    private var network: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Что применить после подключения?", "What should be applied after connecting?")).fontWeight(.medium)
            hint(t("Предзаполнено из ответа сервера и текущих настроек. Изменения ещё не применены.", "Prefilled from the server response and current settings. Changes are not applied yet."))
            HStack { rowLabel(t("Трафик", "Traffic")); mode }
            if state.mode == .selected {
                proposal(title: t("Подсети", "Subnets"), values: state.pendingRoutes.map(\.value), selected: $state.applyRoutes, kind: .routes)
            } else {
                hint(t("Весь IPv4-трафик пойдёт через VPN только после «Применить».", "All IPv4 traffic will use VPN only after you choose Apply."))
            }
            proposal(title: "DNS", values: state.pendingZones.map { $0.zone + " → " + ($0.resolver == "vpn" ? state.serverDNS.joined(separator: ", ") : $0.resolver) }, selected: $state.applyDNS, kind: .dns)
            if state.serverOfferedDefaultRoute {
                hint(t("Сервер предложил весь трафик. Этот режим нужно выбрать вручную.", "The server offered all traffic. Select that mode explicitly to use it."))
            } else if state.pendingRoutes.isEmpty && state.pendingZones.isEmpty {
                hint(state.serverDNS.isEmpty
                     ? t("Сервер не прислал настроек. Можно добавить их вручную или пропустить.", "The server supplied no settings. Add them manually or skip.")
                     : t("DNS сервера: ", "Server DNS: ") + state.serverDNS.joined(separator: ", ") + t(". Домен не передан — укажите его через «Изменить…».", ". No domain supplied — add one using Edit…."))
            }
            if state.showError { Text(networkError).font(.system(size: 12)).foregroundStyle(LabColor.failure) }
        }.padding(24)
    }
    private var networkError: String {
        if state.applyRoutes && state.mode == .selected && !state.pendingRoutes.allSatisfy({ CompactSetupState.validRoute($0.value) }) {
            return t("Исправьте адреса подсетей VPN.", "Correct the VPN subnet addresses.")
        }
        return t("Проверьте домены, серверы и порты DNS.", "Check DNS domains, servers and ports.")
    }
    private func proposal(title: String, values: [String], selected: Binding<Bool>, kind: CompactEditor) -> some View {
        HStack(spacing: 12) {
            Toggle(title, isOn: selected).frame(width: 100, alignment: .leading).disabled(values.isEmpty)
            VStack(alignment: .leading, spacing: 2) {
                Text(values.first ?? t("Не предложены", "None supplied")).lineLimit(1).truncationMode(.middle)
                if values.count > 1 { Text(t("Всего: ", "Total: ") + String(values.count)).foregroundStyle(.secondary) }
            }.font(.system(size: 12)).help(values.joined(separator: "\n"))
            Spacer(minLength: 0)
            Button(t("Изменить…", "Edit…")) { state.edit(kind) }.accessibilityLabel(title + ": " + t("Изменить", "Edit"))
        }.frame(minHeight: 32)
    }
    private func hint(_ text: String) -> some View { Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
    private var system: some View {
        VStack(alignment: .leading, spacing: 16) {
            IconLabel(title: state.helperReady ? t("Система готова", "System ready") : t("Нужен системный помощник", "System helper required"), icon: state.helperReady ? "circle-check" : "triangle-alert")
                .foregroundStyle(state.helperReady ? LabColor.success : LabColor.warning)
            hint(t("Этот шаг появится только при необходимости. В демо установка имитируется.", "This step appears only when needed. Installation is simulated in this demo."))
            Button(t("Имитировать установку", "Simulate installation")) { state.helperReady = true }
        }.padding(24)
    }
    private var verification: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(state.address).fontWeight(.medium).lineLimit(1).truncationMode(.middle).help(state.address)
            if state.connected {
                IconLabel(title: t("Тестовое подключение готово", "Sample connection ready"), icon: "circle-check").foregroundStyle(LabColor.success)
                hint(state.mode == .proxy ? t("Системные маршруты и DNS не меняются в режиме SOCKS.", "SOCKS mode does not change system routes or DNS.") : state.proposalsApplied
                     ? t("Выбранные настройки применены в демо.", "Selected settings applied in this demo.")
                     : t("Предложения сервера пропущены. Прежние настройки сохранены.", "Server suggestions skipped. Previous settings retained."))
                Text(t("Рабочий ресурс · необязательно", "Work resource · optional")).font(.system(size: 12))
                HStack {
                    SingleLineInput(text: $state.resource, label: t("Рабочий ресурс", "Work resource"), placeholder: "https://intranet.example.com").frame(height: 24)
                        .onChange(of: state.resource) { state.accessChecked = false }
                    Button(t("Проверить", "Check")) { state.accessChecked = state.canCheckAccess }.disabled(!state.canCheckAccess)
                }
                if state.accessChecked { hint(t("Тестовый ресурс доступен.", "The sample resource is reachable.")) }
            } else { hint(t("Настройки заполнены. В рабочей версии следующий шаг откроет вход в VPN.", "Settings are complete. In production, the next action opens VPN sign-in.")) }
        }.padding(24)
    }
}

struct CompactListEditor: View {
    @ObservedObject var model: DemoModel
    @ObservedObject var state: CompactSetupState
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    private var routes: Bool { state.editor == .routes }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(routes ? t("Подсети VPN", "VPN subnets") : t("DNS-зоны", "DNS zones")).font(.system(size: 16, weight: .semibold))
            Text(routes ? t("Удалите ненужные подсети или добавьте свои. Пока это черновик.", "Remove unwanted subnets or add your own. This is still a draft.") : t("vpn — DNS от шлюза. Изменения попадут в черновик выбора.", "vpn uses gateway DNS. Edits update the selection draft."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if !routes {
                HStack { Text(t("Домен", "Domain")).frame(maxWidth: .infinity, alignment: .leading); Text(t("DNS-сервер", "DNS server")).frame(width: 128, alignment: .leading); Text(t("Порт", "Port")).frame(width: 54, alignment: .leading); Spacer().frame(width: 26) }.font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    if routes {
                        ForEach($state.draftRoutes) { $row in
                            HStack {
                                SingleLineInput(text: $row.value, label: t("Подсеть", "Subnet"), placeholder: "10.20.0.0/16").frame(height: 24)
                                Button { state.draftRoutes.removeAll { $0.id == row.id } } label: { Lucide(name: "x", size: 14) }.help(t("Удалить подсеть", "Remove subnet"))
                            }
                        }
                    } else {
                        ForEach($state.draftZones) { $zone in
                            HStack {
                                SingleLineInput(text: $zone.zone, label: t("Домен", "Domain"), placeholder: "corp.example.com").frame(height: 24)
                                SingleLineInput(text: $zone.resolver, label: t("DNS-сервер", "DNS server"), placeholder: "vpn").frame(width: 128, height: 24)
                                SingleLineInput(text: $zone.port, label: t("Порт", "Port"), placeholder: "53").frame(width: 54, height: 24)
                                Button { state.draftZones.removeAll { $0.id == zone.id } } label: { Lucide(name: "x", size: 14) }.help(t("Удалить зону", "Remove zone"))
                            }
                        }
                    }
                    if routes ? state.draftRoutes.isEmpty : state.draftZones.isEmpty { Text(t("Список пуст. Добавьте первую строку.", "The list is empty. Add the first row.")).foregroundStyle(.secondary).padding(.top, 24) }
                }.padding(2)
            }.frame(maxHeight: .infinity)
            Button(routes ? t("Добавить подсеть", "Add subnet") : t("Добавить зону", "Add zone")) {
                if routes { state.draftRoutes.append(.init()) } else { state.draftZones.append(.init(zone: "", resolver: "vpn", port: "53")) }
            }
            if state.editorError { Text(t("Исправьте значения перед сохранением.", "Correct the values before saving.")).font(.system(size: 12)).foregroundStyle(LabColor.failure) }
            Divider()
            HStack {
                Button(t("Отмена", "Cancel")) { state.cancelEditor() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(t("Сохранить", "Save")) { state.saveEditor() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 520, height: 360).background(Color(nsColor: .windowBackgroundColor))
    }
}
