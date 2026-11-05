import SwiftUI

struct SetupView: View {
    static let width: CGFloat = 580
    static let height: CGFloat = 610
    @ObservedObject private var flow = SetupFlow.shared
    @ObservedObject private var store: StatusStore
    @Environment(\.dismiss) private var dismiss
    @State private var resource = ""
    @State private var accessResult: Bool?
    @State private var accessChecked = false
    @State private var checkingAccess = false
    @State private var showNetworks = false
    init() {
        if CommandLine.arguments.contains("--stage") {
            var status = Status()
            status.profile = "setup-sample"
            status.state = CommandLine.arguments.contains("connected") ? .connected : .down
            store = StatusStore(preview: status)
        } else { store = .shared }
    }
    private var connected: Bool { flow.savedID != nil && store.status.state == .connected && store.status.profile == flow.savedID }
    private var locked: Bool { flow.busy || flow.checking || store.busy != nil }
    private var staging: Bool { CommandLine.arguments.contains("--stage") }
    private var traffic: Binding<String> {
        Binding(get: { flow.doc.mode == "proxy" ? "proxy" : Set(flow.doc.routeNets) == ["0.0.0.0/1", "128.0.0.0/1"] ? "all" : "selected" }, set: {
            flow.doc.mode = $0 == "proxy" ? "proxy" : "tunnel"
            if $0 == "all" { flow.doc.routes = ["0.0.0.0/1", "128.0.0.0/1"] }
            else if $0 == "selected" && Set(flow.doc.routeNets) == ["0.0.0.0/1", "128.0.0.0/1"] { flow.doc.routes = [] }
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppMark(size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Мастер настройки")).font(.system(size: 20, weight: .semibold))
                    Text(L("От профиля до первого подключения.")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(20)
            HStack(spacing: 10) {
                progress(L("Профиль"), .profile)
                Image(systemName: "chevron.right")
                if flow.includesSystem {
                    progress(L("Система"), .system)
                    Image(systemName: "chevron.right")
                }
                progress(L("Проверка"), .verify)
                Spacer()
            }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 12)
            Divider()
            Form {
                switch flow.step {
                case .profile: profile
                case .system: system
                case .verify: verification
                }
            }.formStyle(.grouped).disabled(locked)
            if let note = flow.note {
                ScrollView { Text(note).font(.system(size: 12)).foregroundStyle(Palette.bad).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(maxHeight: 58).padding(.horizontal, 20)
            }
            Divider()
            HStack {
                if flow.step != .profile { Button(L("Назад")) { flow.back() }.disabled(locked) }
                Button(L("Закрыть")) { dismiss() }.disabled(locked || checkingAccess)
                Spacer()
                if store.busy != nil && !staging { Button(L("Отменить подключение")) { store.cancelCurrent() } }
                if flow.busy || flow.checking { ProgressView().controlSize(.small) }
                if flow.step == .profile {
                    Button(L("Сохранить и продолжить")) { flow.saveAndContinue() }.buttonStyle(.borderedProminent).disabled(locked)
                } else if flow.step == .system {
                    Button(L("Продолжить")) { flow.continueFromSystem() }.buttonStyle(.borderedProminent).disabled(locked || !flow.ready)
                } else {
                    Button(L("Готово")) { dismiss() }.buttonStyle(.borderedProminent).disabled(!connected || checkingAccess)
                }
            }.padding(16)
        }
        .frame(width: Self.width, height: Self.height)
        .onAppear {
            if staging {
                let args = CommandLine.arguments
                func arg(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
                flow.stage(step: Int(arg("--step") ?? "0") ?? 0, state: arg("--setup-state") ?? "empty")
                showNetworks = arg("--setup-state") == "dns"
            }
        }
        .onChange(of: resource) { _, _ in accessChecked = false; accessResult = nil }
        .onChange(of: flow.savedID) { _, _ in resource = flow.doc.health; accessChecked = false; accessResult = nil }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if flow.step == .system && !staging { flow.check() }
        }
    }

    private func progress(_ title: String, _ step: SetupFlow.Step) -> some View {
        Text(title).fontWeight(flow.step == step ? .semibold : .regular)
            .foregroundStyle(flow.step == step ? Color.accentColor : .secondary)
    }
    private var profile: some View {
        Group {
            Section {
                LabeledContent(L("Адрес VPN")) { SetupInput(text: $flow.doc.url, label: L("Адрес VPN"), placeholder: "vpn.example.com/employees") }
                LabeledContent(L("Пользователь")) { SetupInput(text: $flow.doc.user, label: L("Пользователь"), placeholder: L("необязательно")) }
                Picker(L("Как входить"), selection: $flow.doc.auth) {
                    Text(L("SSO в окне браузера")).tag("")
                    Text(L("Пароль и код из SMS")).tag("password")
                }
            } footer: { Text(L("Имя профиля подставим из адреса. Пароль и код вводятся при подключении.")) }
            Section {
                Picker(L("Трафик"), selection: traffic) {
                    Text(L("Выбранные сети")).tag("selected")
                    Text(L("Весь IPv4-трафик")).tag("all")
                    Text(L("Только SOCKS-прокси")).tag("proxy")
                }
                if traffic.wrappedValue == "selected" {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L("Подсети VPN · по одной в строке")).font(.system(size: 12))
                        TextEditor(text: Binding(get: { flow.doc.routes.joined(separator: "\n") }, set: { flow.doc.routes = $0.components(separatedBy: "\n") }))
                            .font(.system(size: 12, design: .monospaced)).frame(height: 48)
                    }
                    if flow.doc.routeNets.isEmpty { Text(L("Укажите рабочие подсети или выберите весь IPv4-трафик. Без маршрутов рабочие ресурсы недоступны.")).font(.system(size: 11)).foregroundStyle(Palette.warn) }
                } else if traffic.wrappedValue == "all" {
                    Text(L("Интернет пойдёт через VPN. Шлюз должен разрешать выход наружу.")).font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text(L("Приложения нужно настроить на SOCKS 127.0.0.1:%@.", flow.doc.proxyPort)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                DisclosureGroup(L("DNS-зоны"), isExpanded: $showNetworks) {
                    ForEach($flow.doc.zones) { $zone in
                        HStack {
                            SetupInput(text: $zone.zone, label: L("Домен"), placeholder: "corp.example.com")
                            SetupInput(text: $zone.resolver, label: L("DNS-сервер"), placeholder: "vpn")
                            Button { flow.doc.zones.removeAll { $0.id == zone.id } } label: { Image(systemName: "minus.circle") }.help(L("Удалить"))
                        }
                    }
                    Button(L("Добавить зону")) { flow.doc.zones.append(ZoneLine(zone: "", resolver: "vpn", port: "")) }
                    Text(L("Домен организации и DNS-сервер: vpn — адрес, полученный от шлюза.")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if flow.savedID == nil {
                Section { Button(L("Открыть готовый профиль…")) { QuickProfileFlow.shared.chooseFile() } }
            }
        }
    }
    private var system: some View {
        Section {
            Label(flow.ready ? L("Система готова") : L("Подготовьте систему"), systemImage: flow.ready ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(flow.ready ? Palette.ok : Palette.warn)
            if !flow.ready {
                if let error = flow.system?.error { Text(error).font(.system(size: 12)).foregroundStyle(Palette.bad) }
                else {
                    Text(L("Для этого профиля нужна системная подготовка. Выполните команду в Терминале, затем проверьте готовность."))
                    HStack {
                        Text("ocmac prepare && sudo ocmac install").font(.ocMono).textSelection(.enabled)
                        CopyButton(text: "ocmac prepare && sudo ocmac install")
                    }
                    Text(L("macOS запросит пароль администратора. Для SOCKS без CSD установка помощника не нужна.")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Button(L("Проверить готовность")) { flow.check() }
        }
    }
    private var verification: some View {
        Group {
            Section {
                Text(flow.doc.name).fontWeight(.medium).lineLimit(1).truncationMode(.middle).help(flow.doc.url)
                if connected {
                    Label(L("VPN подключён"), systemImage: "checkmark.circle").foregroundStyle(Palette.ok)
                } else {
                    Text(L("Войдите в окне своей организации. После входа можно проверить рабочий ресурс.")).font(.system(size: 12)).foregroundStyle(.secondary)
                    if store.status.state == .connected && store.status.profile != flow.savedID {
                        Text(L("Это подключение заменит текущее VPN-соединение.")).font(.system(size: 12)).foregroundStyle(Palette.warn)
                    }
                    Button(store.busy ?? L("Подключиться…")) { flow.connect() }.buttonStyle(.borderedProminent).disabled(locked)
                }
                if let note = store.actionNote, !staging { Text(note).font(.system(size: 12)).foregroundStyle(Palette.warn).textSelection(.enabled) }
            }
            Section {
                SetupInput(text: $resource, label: L("Рабочий ресурс"), placeholder: "https://intranet.example.com")
                Button(L("Проверить доступ")) { checkAccess() }.disabled(!connected || resource.trimmed.isEmpty || checkingAccess)
                if checkingAccess { ProgressView(L("Проверяю доступ…")) }
                else if accessChecked {
                    Text(accessResult == true ? L("Рабочий ресурс отвечает") : L("Ресурс не отвечает. Откройте диагностику, чтобы проверить сети и DNS."))
                        .font(.system(size: 12)).foregroundStyle(accessResult == true ? Palette.ok : Palette.warn)
                    if accessResult != true { Button(L("Открыть диагностику")) { WindowBridge.open(WindowID.diagnostics) } }
                }
            } header: { Text(L("Рабочий ресурс · необязательно")) }
        }
    }
    private func checkAccess() {
        guard connected, !checkingAccess, let id = flow.savedID, !resource.trimmed.isEmpty else { return }
        let target = resource.trimmed
        checkingAccess = true; accessChecked = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = OCMacClient.shared.checkResource(target, profile: id)
            DispatchQueue.main.async {
                checkingAccess = false
                guard connected, flow.savedID == id, resource.trimmed == target else { return }
                accessChecked = true; accessResult = result
            }
        }
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
