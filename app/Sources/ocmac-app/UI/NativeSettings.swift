import AppKit
import SwiftUI

/// Shared, plain macOS layout. Groups have no material/bevel overlay; only lists
/// and secondary editors need scrolling. Input widgets remain native controls.
struct NativeForm<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.background(Color(nsColor: .windowBackgroundColor))
    }
}
struct NativeSection<Content: View, Header: View, Footer: View>: View {
    let content: Content
    let header: Header
    let footer: Footer
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
        self.content = content(); self.header = header(); self.footer = footer()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header.font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) { content }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
            footer.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
extension NativeSection where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) { self.init(content: content, header: { EmptyView() }, footer: { EmptyView() }) }
}
extension NativeSection where Header == Text, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) { self.init(content: content, header: { Text(title) }, footer: { EmptyView() }) }
}
extension NativeSection where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) { self.init(content: content, header: header, footer: { EmptyView() }) }
}
extension NativeSection where Header == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) { self.init(content: content, header: { EmptyView() }, footer: footer) }
}

struct SettingsIcon: View {
    let name: String
    var size: CGFloat = 17
    private static var cache: [String: NSImage] = [:]
    private var image: NSImage? {
        if let image = Self.cache[name] { return image }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Lucide/\(name).svg"), let image = NSImage(contentsOf: url) else { return nil }
        Self.cache[name] = image; return image
    }
    var body: some View {
        if let icon = image {
            Image(nsImage: icon).resizable().renderingMode(.template).scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
        } else { Image(systemName: "circle").frame(width: size, height: size).accessibilityHidden(true) }
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case connection, login, network, advanced, general, notifications, diagnostics, logs, about
    var id: String { rawValue }
    var isProfile: Bool { [.connection, .login, .network, .advanced].contains(self) }
    var title: String {
        switch self {
        case .connection: return L("Подключение")
        case .login: return L("Вход")
        case .network: return L("Сеть")
        case .advanced: return L("Дополнительно")
        case .general: return L("Приложение")
        case .notifications: return L("Уведомления")
        case .diagnostics: return L("Диагностика")
        case .logs: return L("Журналы")
        case .about: return L("О программе")
        }
    }
    var icon: String {
        switch self {
        case .connection: return "network"
        case .login: return "key-round"
        case .network: return "route"
        case .advanced: return "sliders-horizontal"
        case .general: return "settings"
        case .notifications: return "bell"
        case .diagnostics: return "activity"
        case .logs: return "mail"
        case .about: return "info"
        }
    }
    static var initial: SettingsPage {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--settings-page"), i + 1 < args.count, let page = SettingsPage(rawValue: args[i+1]) { return page }
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count {
            return ["1": .notifications, "2": .general, "3": .about][args[i+1]] ?? .connection
        }
        return .connection
    }
}
