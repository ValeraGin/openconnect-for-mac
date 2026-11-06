import SwiftUI

enum AppInfo {
    // Версия одна на всех — VERSION в bin/ocmac. make-app.sh кладёт её в
    // Info.plist, отсюда она и читается; вторую константу в коде заводить
    // незачем: они уже расходились.
    static let version: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return (v?.isEmpty == false) ? v! : L("из исходников (без бандла)")
    }()
}

// Окно «о программе»: версии всех частей и где что лежит. Полезно не из
// вежливости — по этим строкам видно, что хелпер отстал от CLI или что
// openconnect обновился и манифест доверия разошёлся.
struct AboutView: View {
    @State private var v: [String: String] = [:]
    @Environment(\.openWindow) private var openWindow

    @State private var detail: String?
    private var stageDetail: String? {
        let args = CommandLine.arguments
        guard args.contains("--stage"), let i = args.firstIndex(of: "--about-detail"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    var body: some View {
        Group { if stageDetail != nil { detailEditor } else { overview } }
            .onAppear { detail = stageDetail; load() }
            .sheet(isPresented: Binding(get: { detail != nil && stageDetail == nil }, set: { if !$0 { detail = nil } })) { detailEditor }
    }
    private var overview: some View {
        NativeForm {
            VStack(alignment: .leading, spacing: 10) {
                AppMark(size: 64)
                Text("OpenConnect for Mac").font(.system(size: 21, weight: .semibold))
                Text(AppInfo.version).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                Text(L("Клиент OpenConnect для macOS: SSO, split DNS, split tunneling"))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(L("Независимый проект. Не связан с проектом OpenConnect или Cisco."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            NativeSection {
                NativeNavigationRow(title: L("Компоненты")) { detail = "components" }
                NativeNavigationRow(title: L("Где что лежит")) { detail = "files" }
                NativeNavigationRow(title: L("Лицензии")) { detail = "licenses" }
            }
            Text(L("ValeraGin — Ignatkovich Valery · лицензия MIT")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var detailEditor: some View {
            VStack(spacing: 0) {
                HStack { Text(detail == "components" ? L("Компоненты") : detail == "files" ? L("Где что лежит") : L("Лицензии")).font(.headline); Spacer() }.padding(20)
                Divider()
                NativeForm {
                    if detail == "components" { components }
                    else if detail == "files" { locations }
                    else {
                        Text("OpenConnect for Mac — MIT").font(.headline)
                        Text("Lucide — ISC / MIT").font(.headline)
                        if let url = Bundle.main.resourceURL?.appendingPathComponent("Lucide/LICENSE"), let license = try? String(contentsOf: url) {
                            Text(license).font(.caption).textSelection(.enabled)
                        }
                    }
                }
                Divider()
                HStack { Spacer(); Button(L("Готово")) { detail = nil }.keyboardShortcut(.defaultAction) }.padding(16)
            }.frame(width: 520, height: 460)
    }
    private var components: some View {
            NativeSection {
                part(L("Приложение"), AppInfo.version, Bundle.main.executablePath ?? "")
                part(L("Клиент OpenConnect for Mac"), v["ocmac"], v["ocmac_path"])
                part(L("Хелпер (root)"), helperVersion, v["helper_path"])
                part("openconnect", v["openconnect"], v["openconnect_path"])
                part(L("Копия для root"), nil, v["openconnect_root"])
                part(L("Аутентификатор"), L("как OpenConnect for Mac"), v["auth_path"])
            } footer: {
                Footnote(L("Приложению права не нужны: всё привилегированное делает хелпер. ")
                     + (GlobalHotkeys.shared.isRegistered("pause")
                        ? L("Пауза — ⌥⌘P из любой программы.") : L("⌥⌘P занято другой программой: пауза только из меню.")))
            }
    }
    private var locations: some View {
            NativeSection {
                HStack {
                    Button(L("Журналы")) { WindowBridge.open(WindowID.logs) }
                    Button(L("Диагностика")) { WindowBridge.open(WindowID.diagnostics) }
                    Spacer()
                }
                reveal(L("Каталог конфигурации"), v["config_dir"] ?? OCMacClient.shared.configDir)
                reveal(L("Приложение"), v["app_path"] ?? (Bundle.main.bundlePath))
                reveal(L("Журнал супервизора"), v["supervisor_log"] ?? OCMacClient.shared.supervisorLog)
                reveal(L("Журнал openconnect"), v["openconnect_log"] ?? OCMacClient.shared.openconnectLog)
                reveal(L("Журнал приложения"), AppLog.path)
            }
    }

    private var helperVersion: String? {
        guard let version = v["helper"], !version.isEmpty else { return nil }
        return v["helper_nopasswd"] == "1" ? version : version + L(" · без NOPASSWD")
    }

    private func part(_ title: String, _ version: String?, _ path: String?) -> some View {
        Group {
            if let path, !path.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(title).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(version ?? "—").font(.system(size: 12, design: .monospaced))
                            .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                    }
                    Text(Self.short(path)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).help(path)
                }
            }
        }
    }

    /// Путь с «~» вместо домашнего каталога: короче и не светит имя учётной записи.
    static func short(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

    private func reveal(_ title: String, _ path: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            } label: {
                Text(Self.short(path)).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.link).help(L("Показать в Finder"))
        }
    }

    private func load() {
        if CommandLine.arguments.contains("--stage") {
            v = ["ocmac": AppInfo.version, "ocmac_path": "/opt/homebrew/bin/ocmac",
                 "helper": AppInfo.version, "helper_nopasswd": "1", "helper_path": "/usr/local/libexec/ocmac-helper",
                 "openconnect": "9.12", "openconnect_path": "/opt/homebrew/bin/openconnect",
                 "auth_path": "/opt/homebrew/libexec/ocmac-auth"]
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let map = OCMacClient.shared.versions(maxAge: 5)
            DispatchQueue.main.async { v = map }
        }
    }
}

enum WindowID {
    static let connection = "connection"
    static let quickProfile = "quick-profile"
    static let settings = "settings"
    static let logs = "logs"
    static let diagnostics = "diagnostics"
    static let setup = "setup"
}
