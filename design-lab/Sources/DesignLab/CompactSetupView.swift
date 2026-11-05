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
                if state.step == .verify {
                    Button(state.connected ? t("Начать заново", "Start again") : t("Проверить подключение", "Test connection")) {
                        if state.connected { state.reset() } else { state.connected = true }
                    }.buttonStyle(.borderedProminent)
                } else {
                    Button(t("Продолжить", "Continue")) { state.next() }.buttonStyle(.borderedProminent)
                        .disabled(state.step == .system && !state.helperReady)
                }
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
    private var stepTitle: String {
        switch state.step {
        case .connection: return t("1 · Подключение", "1 · Connection")
        case .network: return t("2 · Сеть", "2 · Network")
        case .system: return t("3 · Система", "3 · System")
        case .verify: return state.includedSystem ? t("4 · Проверка", "4 · Verify") : t("3 · Проверка", "3 · Verify")
        }
    }
    private var connection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.layout == .library {
                Settings.Container(contentWidth: 500) {
                    Settings.Section(title: t("Адрес VPN:", "VPN address:")) { address.frame(width: 350) }
                    Settings.Section(title: t("Пользователь:", "Username:")) { username.frame(width: 350) }
                    Settings.Section(title: t("Вход:", "Sign-in:")) { login.frame(width: 350) }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                    GridRow { rowLabel(t("Адрес VPN", "VPN address")); address }
                    GridRow { rowLabel(t("Пользователь", "Username")); username }
                    GridRow { rowLabel(t("Вход", "Sign-in")); login }
                }.padding(24)
            }
            Text(t("Адрес станет именем профиля. Пароль и код — при подключении.", "The address becomes the profile name. Enter your password and code when connecting."))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 24)
            if state.showError {
                Label(t("Укажите адрес VPN с HTTPS.", "Enter an HTTPS VPN address."), systemImage: "exclamationmark.circle")
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
    private var mode: some View {
        Picker(t("Трафик", "Traffic"), selection: $state.mode) {
            Text(t("Выбранные сети", "Selected networks")).tag(RouteMode.selected)
            Text(t("Весь IPv4-трафик", "All IPv4 traffic")).tag(RouteMode.all)
            Text(t("Только SOCKS-прокси", "SOCKS proxy only")).tag(RouteMode.proxy)
        }.labelsHidden()
    }
    private var network: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { rowLabel(t("Трафик", "Traffic")); mode }
            if state.mode == .proxy {
                HStack { rowLabel(t("Порт SOCKS", "SOCKS port")); SingleLineInput(text: $state.port, label: t("Порт SOCKS", "SOCKS port")).frame(width: 100, height: 24); Spacer() }
                Toggle(t("Использовать как системный SOCKS", "Use as system SOCKS"), isOn: $state.systemProxy)
                hint(t("Прокси используют приложения с поддержкой SOCKS.", "Apps must support SOCKS to use this proxy."))
            } else {
                if state.mode == .selected {
                    summary(title: t("Подсети", "Subnets"), value: state.routes.isEmpty ? t("Не заданы", "Not configured") : t("Добавлено: ", "Configured: ") + String(state.routes.count), kind: .routes)
                } else {
                    hint(t("Интернет пойдёт через VPN. Шлюз должен разрешать выход наружу.", "Internet traffic will use the VPN. The gateway must allow internet access."))
                }
                summary(title: "DNS", value: state.zones.isEmpty ? t("Не настроен", "Not configured") : t("Зон: ", "Zones: ") + String(state.zones.count), kind: .dns)
                hint(t("Укажите сети и домены, доступные через VPN.", "Configure networks and domains reachable through the VPN."))
            }
            if state.showError { Text(networkError)
                .font(.system(size: 12)).foregroundStyle(LabColor.failure) }
        }.padding(24)
    }
    private var networkError: String {
        if state.mode == .proxy { return t("Укажите порт от 1 до 65535.", "Enter a port from 1 to 65535.") }
        if state.mode == .selected && state.routes.isEmpty { return t("Добавьте хотя бы одну подсеть VPN.", "Add at least one VPN subnet.") }
        if state.mode == .selected && !state.routes.allSatisfy({ CompactSetupState.validRoute($0.value) }) {
            return t("Исправьте адреса подсетей VPN.", "Correct the VPN subnet addresses.")
        }
        return t("Проверьте домены, серверы и порты DNS.", "Check DNS domains, servers and ports.")
    }
    private func summary(title: String, value: String, kind: CompactEditor) -> some View {
        HStack {
            rowLabel(title)
            Text(value).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Button(t("Изменить…", "Edit…")) { state.edit(kind) }
                .accessibilityLabel(title + ": " + t("Изменить", "Edit"))
        }.frame(height: 28)
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
            Text(routes ? t("По одной подсети в строке, например 10.20.0.0/16.", "One subnet per row, for example 10.20.0.0/16.") : t("vpn — DNS-сервер, полученный от шлюза.", "vpn uses the DNS server supplied by the gateway."))
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
