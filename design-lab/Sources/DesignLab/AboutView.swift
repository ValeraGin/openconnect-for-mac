import SwiftUI

struct AboutView: View {
    @ObservedObject var model: DemoModel
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    private var license: String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Lucide/LICENSE") else { return "" }
        return (try? String(contentsOf: url)) ?? ""
    }
    private var settingsLicense: String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Settings-LICENSE") else { return "" }
        return (try? String(contentsOf: url)) ?? ""
    }
    var body: some View {
        VStack(spacing: 16) {
            if model.aboutLicenses {
                HStack {
                    Text(t("Лицензии", "Licenses")).font(.title2.weight(.semibold))
                    Spacer()
                    Button(t("Назад", "Back")) { model.aboutLicenses = false }
                }
                ScrollView {
                    Text("Lucide icons\n\n" + license + "\n\nSettings 3.0.0\n\n" + settingsLicense).font(.system(size: 12))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if model.aboutTechnical {
                HStack {
                    Text(t("Компоненты и файлы", "Components and files")).font(.title2.weight(.semibold))
                    Spacer()
                    Button(t("Назад", "Back")) { model.aboutTechnical = false }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(t("Пример сведений. Версии и пути не считываются с вашего Мака.", "Sample information. Versions and paths are not read from your Mac."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        ForEach([("OpenConnect for Mac", "0.4 · Demo"), ("CLI / helper / auth", "Demo"), ("openconnect / ocproxy", "Demo")], id: \.0) { name, version in
                            info(name, value: version)
                        }
                        Divider()
                        Text(t("Где что лежит", "File locations")).font(.headline)
                        Text("~/.config/ocmac/\n~/.config/ocmac/profiles/\n~/Library/Logs/OpenConnect for Mac/")
                            .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        Text(t("В рабочем приложении доступны путь к каждой программе, статус помощника и открытие файлов в Finder.", "Production shows each executable’s path, helper status and Reveal in Finder actions."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        HStack {
                            Button(t("Журналы", "Logs")) { model.aboutPresented = false; model.navigate(.logs) }
                            Button(t("Диагностика", "Diagnostics")) { model.aboutPresented = false; model.detail = nil; model.page = .diagnostics }
                        }
                        Text(t("Пауза — ⌥⌘P. Выход из рабочего приложения не останавливает туннель.", "Pause: ⌥⌘P. Quitting the production app does not stop its tunnel."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            } else {
                BrandMark(size: 76)
                VStack(spacing: 5) {
                    Text("OpenConnect for Mac").font(.system(size: 25, weight: .semibold))
                    Text(t("Демо интерфейса 0.4", "Interface demo 0.4")).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Text(t("Простой VPN-клиент для macOS.\nПрототип нового интерфейса.",
                       "A simple VPN client for macOS.\nA prototype of the new interface."))
                    .font(.system(size: 13)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    info(t("Автор", "Author"), value: "ValeraGin")
                    info(t("Лицензия приложения", "App license"), value: "MIT")
                    info(t("Иконки", "Icons"), value: "Lucide · ISC / MIT")
                }.padding(14).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 20) {
                    Link(destination: URL(string: "https://github.com/ValeraGin/openconnect-for-mac")!) {
                        IconLabel(title: "GitHub", icon: "external-link")
                    }
                    Button(t("Лицензии", "Licenses")) { model.aboutLicenses = true }.buttonStyle(.link)
                }.foregroundStyle(LabColor.accent)
                Button(t("Компоненты, файлы и диагностика…", "Components, files and diagnostics…")) { model.aboutTechnical = true }.buttonStyle(.link)
                Text(t("Демо работает только с тестовыми данными.", "This demo uses sample data only."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Divider()
            HStack {
                Text("© 2026 ValeraGin").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(t("Закрыть", "Close")) { model.aboutPresented = false }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(28).frame(width: 440, height: 540)
        .background(Color(nsColor: .windowBackgroundColor)).tint(LabColor.accent)
    }
    private func info(_ title: String, value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value) }.font(.system(size: 12))
    }
}
