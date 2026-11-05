import SwiftUI

struct SetupView: View {
    static let width: CGFloat = 560
    static let height: CGFloat = 460
    @ObservedObject private var flow = SetupFlow.shared
    @ObservedObject private var store: StatusStore
    @Environment(\.dismiss) private var dismiss
    @State private var resource = ""
    @State private var accessResult: Bool?
    @State private var accessChecked = false
    @State private var checkingAccess = false
    @State private var editor: NetworkEditor?
    enum NetworkEditor: String, Identifiable { case routes, dns; var id: String { rawValue } }
    init() {
        if CommandLine.arguments.contains("--stage") {
            var status = Status(); status.profile = "setup-sample"
            status.state = CommandLine.arguments.contains("connected") ? .connected : .down
            store = StatusStore(preview: status)
        } else { store = .shared }
    }
    private var connected: Bool { flow.savedID != nil && store.status.state == .connected && store.status.profile == flow.savedID }
    private var locked: Bool { flow.busy || flow.checking || store.busy != nil }
    private var staging: Bool { CommandLine.arguments.contains("--stage") }
    private var stepTitle: String {
        switch flow.step {
        case .profile: return L("Подключение")
        case .system: return L("Система")
        case .network: return L("После входа · Сеть")
        case .verify: return connected ? L("Проверка") : L("Вход")
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppMark(size: 28)
                Text(L("Настройка подключения")).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(stepTitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(20)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                switch flow.step {
                case .profile: profile
                case .system: system
                case .verify: verification
                case .network: network
                }
                Spacer(minLength: 0)
            }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).disabled(locked)
            if let note = flow.note {
                ScrollView { Text(note).font(.system(size: 12)).foregroundStyle(Palette.bad).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(maxHeight: 48).padding(.horizontal, 20).padding(.bottom, 8)
            }
            Divider()
            HStack {
                if flow.step != .profile { Button(L("Назад")) { flow.back() }.disabled(locked) }
                Button(L("Закрыть")) { dismiss() }.disabled(locked || checkingAccess)
                Spacer()
                if flow.busy || flow.checking { ProgressView().controlSize(.small) }
                switch flow.step {
                case .profile:
                    Button(L("Продолжить")) { flow.saveAndContinue() }.buttonStyle(.borderedProminent).disabled(locked)
                case .system:
                    Button(L("Продолжить")) { flow.continueFromSystem() }.buttonStyle(.borderedProminent).disabled(locked || !flow.ready)
                case .network:
                    Button(L("Не применять")) { flow.skipNetworks() }.disabled(locked)
                    Button(L("Применить")) { flow.applyNetworks() }.buttonStyle(.borderedProminent).disabled(locked || (!connected && !staging))
                case .verify:
                    if store.busy != nil && !staging { Button(L("Отменить подключение")) { store.cancelCurrent() } }
                    else if connected { Button(L("Готово")) { dismiss() }.buttonStyle(.borderedProminent).disabled(checkingAccess) }
                    else { Button(L("Подключиться…")) { flow.connect() }.buttonStyle(.borderedProminent).disabled(locked) }
                }
            }.padding(16)
        }.frame(width: Self.width, height: Self.height).background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editor) { SetupNetworkEditor(kind: $0, flow: flow) }
        .onAppear {
            if staging {
                let args = CommandLine.arguments
                func arg(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
                flow.stage(step: Int(arg("--step") ?? "0") ?? 0, state: arg("--setup-state") ?? "empty")
            }
        }
        .onReceive(store.$status) { if !staging { flow.observe($0, actionBusy: store.busy != nil) } }
        .onChange(of: store.busy) { _, busy in if !staging { flow.observe(store.status, actionBusy: busy != nil) } }
        .onChange(of: resource) { _, _ in accessChecked = false; accessResult = nil }
        .onChange(of: flow.savedID) { _, _ in resource = flow.doc.health; accessChecked = false; accessResult = nil }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if flow.step == .system && !staging { flow.check() }
        }
    }
    private func hint(_ text: String) -> some View { Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
    private func label(_ text: String) -> some View { Text(text).font(.system(size: 12)).frame(width: 100, alignment: .leading) }
    private var profile: some View {
        Group {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow { label(L("Адрес VPN")); SetupInput(text: $flow.doc.url, label: L("Адрес VPN"), placeholder: "vpn.example.com/employees").frame(height: 24) }
                GridRow { label(L("Пользователь")); SetupInput(text: $flow.doc.user, label: L("Пользователь"), placeholder: L("необязательно")).frame(height: 24) }
                GridRow {
                    label(L("Как входить"))
                    Picker(L("Как входить"), selection: $flow.doc.auth) {
                        Text(L("SSO в окне браузера")).tag("")
                        Text(L("Пароль и код из SMS")).tag("password")
                    }.labelsHidden()
                }
                GridRow {
                    label(L("Режим"))
                    Picker(L("Режим"), selection: $flow.doc.mode) {
                        Text(L("VPN-туннель")).tag("tunnel")
                        Text(L("Только SOCKS-прокси")).tag("proxy")
                    }.labelsHidden()
                }
            }
            if flow.doc.mode == "proxy" {
                HStack {
                    label(L("Порт SOCKS"))
                    SetupInput(text: $flow.doc.proxyPort, label: L("Порт SOCKS")).frame(width: 70, height: 24)
                }
            }
            hint(L("Имя профиля подставим из адреса. Пароль и код вводятся при подключении."))
            hint(L("Подсети и DNS предложим после входа, когда сервер передаст настройки."))
            if flow.savedID == nil { Button(L("Открыть готовый профиль…")) { QuickProfileFlow.shared.chooseFile() }.buttonStyle(.link) }
        }
    }
    private var network: some View {
        Group {
            Text(L("Что применить после подключения?")).fontWeight(.medium)
            hint(L("Выберите, что добавить из ответа сервера. Существующие настройки профиля сохранятся."))
            Toggle(L("Весь IPv4-трафик через VPN"), isOn: $flow.fullTunnel)
            if !flow.fullTunnel {
                HStack {
                    Toggle(L("Подсети"), isOn: $flow.useRoutes).frame(width: 100, alignment: .leading).disabled(flow.proposedRoutes.isEmpty)
                    Text(flow.proposedRoutes.first ?? L("Не предложены")).font(.system(size: 12)).lineLimit(1)
                    if flow.proposedRoutes.count > 1 { Text("+\(flow.proposedRoutes.count - 1)").foregroundStyle(.secondary) }
                    Spacer(minLength: 0)
                    Button(L("Изменить…")) { editor = .routes }
                }
            }
            HStack {
                Toggle("DNS", isOn: $flow.useDNS).frame(width: 100, alignment: .leading).disabled(flow.proposedZones.isEmpty)
                Text(flow.proposedZones.first?.zone ?? L("Не предложены")).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                Button(L("Изменить…")) { editor = .dns }
            }
            if !flow.serverDNS.isEmpty { hint(L("DNS сервера: %@", flow.serverDNS.joined(separator: ", "))) }
            if flow.offeredFullTunnel { hint(L("Сервер предложил широкие маршруты. Весь трафик включается только вашим выбором.")) }
            else if flow.proposedRoutes.isEmpty && flow.proposedZones.isEmpty { hint(L("Новых подсетей и DNS-зон нет. Можно добавить вручную или пропустить.")) }
        }
    }
    private var system: some View {
        Group {
            Label(flow.ready ? L("Система готова") : L("Подготовьте систему"), systemImage: flow.ready ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(flow.ready ? Palette.ok : Palette.warn)
            if !flow.ready {
                if let error = flow.system?.error { hint(error) }
                else {
                    hint(L("Для этого профиля нужна системная подготовка. Выполните команду в Терминале, затем проверьте готовность."))
                    HStack { Text("ocmac prepare && sudo ocmac install").font(.ocMono).textSelection(.enabled); CopyButton(text: "ocmac prepare && sudo ocmac install") }
                    hint(L("macOS запросит пароль администратора. Для SOCKS без CSD установка помощника не нужна."))
                }
            }
            Button(L("Проверить готовность")) { flow.check() }
        }
    }
    private var verification: some View {
        Group {
            Text(flow.doc.name).fontWeight(.medium).lineLimit(1).truncationMode(.middle).help(flow.doc.url)
            if connected {
                Label(L("VPN подключён"), systemImage: "checkmark.circle").foregroundStyle(Palette.ok)
                if !store.status.isProxySession {
                    Button(L("Получить настройки сервера")) { flow.review(store.status) }
                }
                hint(L("Рабочий ресурс · необязательно"))
                HStack {
                    SetupInput(text: $resource, label: L("Рабочий ресурс"), placeholder: "https://intranet.example.com").frame(height: 24)
                    Button(L("Проверить доступ")) { checkAccess() }.disabled(resource.trimmed.isEmpty || checkingAccess)
                }
                if checkingAccess { ProgressView().controlSize(.small) }
                else if accessChecked {
                    hint(accessResult == true ? L("Рабочий ресурс отвечает") : L("Ресурс не отвечает. Откройте диагностику, чтобы проверить сети и DNS."))
                }
            } else {
                hint(L("Войдите в окне своей организации. После входа появится выбор подсетей и DNS от сервера."))
                if store.status.state == .connected && store.status.profile != flow.savedID { hint(L("Это подключение заменит текущее VPN-соединение.")) }
                if let busy = store.busy { ProgressView(busy).controlSize(.small) }
            }
            if let note = store.actionNote, !staging { hint(note) }
        }
    }
    private func checkAccess() {
        guard connected, !checkingAccess, let id = flow.savedID, !resource.trimmed.isEmpty else { return }
        let target = resource.trimmed, session = store.status.gatewaySession
        checkingAccess = true; accessChecked = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = OCMacClient.shared.checkResource(target, profile: id)
            DispatchQueue.main.async {
                checkingAccess = false
                guard connected, flow.savedID == id, resource.trimmed == target, store.status.gatewaySession == session else { return }
                accessChecked = true; accessResult = result
            }
        }
    }
}

private struct SetupNetworkEditor: View {
    let kind: SetupView.NetworkEditor
    @ObservedObject var flow: SetupFlow
    @Environment(\.dismiss) private var dismiss
    @State private var routes: [RouteRow] = []
    @State private var zones: [ZoneLine] = []
    @State private var invalid = false
    private struct RouteRow: Identifiable { let id = UUID(); var value: String }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind == .routes ? L("Подсети VPN") : L("DNS-зоны")).font(.system(size: 16, weight: .semibold))
            Text(L("Это предложения. Они применятся после подтверждения в мастере.")).font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    if kind == .routes {
                        ForEach($routes) { $row in
                            HStack {
                                SetupInput(text: $row.value, label: L("Подсеть"), placeholder: "10.20.0.0/16").frame(height: 24)
                                Button { routes.removeAll { $0.id == row.id } } label: { Image(systemName: "xmark") }.help(L("Удалить"))
                            }
                        }
                    } else {
                        ForEach($zones) { $zone in
                            HStack {
                                SetupInput(text: $zone.zone, label: L("Домен"), placeholder: "corp.example.com").frame(height: 24)
                                SetupInput(text: $zone.resolver, label: L("DNS-сервер"), placeholder: "vpn").frame(width: 120, height: 24)
                                SetupInput(text: $zone.port, label: L("Порт"), placeholder: "53").frame(width: 50, height: 24)
                                Button { zones.removeAll { $0.id == zone.id } } label: { Image(systemName: "xmark") }.help(L("Удалить"))
                            }
                        }
                    }
                }.padding(2)
            }
            Button(kind == .routes ? L("Добавить подсеть") : L("Добавить зону")) {
                if kind == .routes { routes.append(RouteRow(value: "")) } else { zones.append(ZoneLine(zone: "", resolver: "vpn", port: "53")) }
            }
            if invalid { Text(L("Исправьте значения перед сохранением.")).foregroundStyle(Palette.bad).font(.system(size: 12)) }
            Divider()
            HStack {
                Button(L("Отмена")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L("Сохранить")) { save() }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 520, height: 360)
        .onAppear { routes = flow.proposedRoutes.map { RouteRow(value: $0) }; zones = flow.proposedZones }
    }
    private func save() {
        if kind == .routes {
            let values = routes.map { $0.value.trimmed }
            guard values.allSatisfy({ ProfileCheck.validCIDR($0) && ProfileCheck.prefixLength($0) != 0 }) else { invalid = true; return }
            flow.proposedRoutes = values; flow.useRoutes = !values.isEmpty
        } else {
            guard zones.allSatisfy({ ProfileCheck.validZone($0.zone) && ($0.resolver == "vpn" || ProfileCheck.validIP($0.resolver)) && ($0.port.isEmpty || ProfileCheck.validPort($0.port)) }) else { invalid = true; return }
            flow.proposedZones = zones; flow.useDNS = !zones.isEmpty
        }
        dismiss()
    }
}
/// AppKit keeps address/login fields single-line even with long pasted text.
private struct SetupInput: NSViewRepresentable {
    @Binding var text: String
    let label: String
    var placeholder = ""
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.isEditable = true; field.isSelectable = true; field.isBezeled = true
        field.bezelStyle = .roundedBezel; field.font = .systemFont(ofSize: 13)
        field.usesSingleLineMode = true; field.maximumNumberOfLines = 1
        field.cell?.wraps = false; field.cell?.isScrollable = true
        field.lineBreakMode = .byTruncatingMiddle; field.delegate = context.coordinator
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = placeholder; field.toolTip = text
        field.setAccessibilityLabel(label)
        field.isEnabled = context.environment.isEnabled
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SetupInput
        init(_ parent: SetupInput) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let value = field.stringValue.components(separatedBy: .newlines).joined()
            if value != field.stringValue { field.stringValue = value }
            parent.text = value
        }
    }
}
