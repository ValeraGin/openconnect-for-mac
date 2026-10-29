import SwiftUI

struct AboutView: View {
    @ObservedObject var model: DemoModel
    private func t(_ ru: String, _ en: String) -> String { model.t(ru, en) }
    private var license: String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Lucide/LICENSE") else { return "" }
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
                    Text("Lucide icons\n\n" + license).font(.system(size: 12))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Lucide(name: "shield", size: 40).foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading,
                                               endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
                VStack(spacing: 5) {
                    Text("OpenConnect").font(.system(size: 25, weight: .semibold))
                    Text("Design Lab 0.2").font(.system(size: 13)).foregroundStyle(.secondary)
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
