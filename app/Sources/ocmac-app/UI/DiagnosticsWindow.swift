import SwiftUI

// Окно диагностики: вывод `ocmac doctor` как есть, моноширинным, с кнопкой
// «повторить». Здесь же уборка — единственное действие, которое меняет
// систему, поэтому рядом написано, что именно она делает.
struct DiagnosticsView: View {
    var embedded = false
    @ObservedObject private var store = StatusStore.shared
    @Environment(\.openWindow) private var openWindow
    @State private var text = ""
    @State private var running = false
    @State private var stamp: Date?
    @State private var cleanupPending = false
    @State private var reporting = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                Text(text.isEmpty ? (running ? L("проверяю…") : "—") : text)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Palette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            Divider()
            cleanupBar
        }
        .frame(minWidth: embedded ? 0 : 640, minHeight: embedded ? 0 : 420)
        .onAppear { run() }
        // Результат уборки виден в повторной диагностике — когда уборка
        // закончится, а не через три секунды наугад.
        .onChange(of: store.finishedActions) { _ in
            if cleanupPending { cleanupPending = false; run() }
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(L("Диагностика"), systemImage: "stethoscope").fontWeight(.semibold)
                Spacer()
                if running { ProgressView().controlSize(.small) }
                if let stamp { Text(Self.clock.string(from: stamp)).font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Button(L("Повторить")) { run() }.disabled(running)
                Button(L("Сохранить отчёт…")) { saveReport() }.disabled(reporting || store.busy != nil)
                Spacer()
                Button(L("Журналы…")) { WindowBridge.open(WindowID.logs) }
            }
        }.padding(16)
    }

    // Отчёт для разбора: один файл с версиями, диагностикой и хвостами
    // журналов; корпоративные подробности в нём скрыты (ocmac report).
    private func saveReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ocmac-report-\(Self.stamp.string(from: Date())).txt"
        panel.message = L("Адреса, домены и логины в отчёте заменены метками. Перед отправкой посмотрите файл.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        reporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let r = OCMacClient.shared.report(to: url.path)
            DispatchQueue.main.async {
                reporting = false
                if case .failed(_, let why) = r {
                    text = L("отчёт не сохранился: ") + why + "\n\n" + text
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmm"; return f
    }()

    private var cleanupBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Уборка следов прошлой сессии")).font(.system(size: 12, weight: .medium))
                Text(L("Снимает то, что осталось после падения: наши зоны в /etc/resolver, наши маршруты, ")
                     + L("системный SOCKS без живого прокси. Системный DNS не трогает — OpenConnect for Mac его не ставит. ")
                     + L("Живой туннель и чужой openconnect не трогает. То же, что `ocmac cleanup`."))
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = store.actionNote {
                    Text(note).font(.system(size: 11))
                        .foregroundStyle(store.actionFailed ? Palette.bad : Palette.ok)
                }
            }
            Spacer()
            Button(L("Убрать")) {
                cleanupPending = true
                store.cleanup()
            }
            .disabled(store.busy != nil)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    private func run() {
        guard !running else { return }
        if CommandLine.arguments.contains("--stage") {
            text = CommandLine.arguments.contains("--diagnostic-error") ? "[FAIL] vpn.example.com: connection timed out" : "[ OK ] Client installed\n[ OK ] Profile valid\n[ OK ] Helper ready\n[ OK ] DNS configuration"
            return
        }
        running = true
        DispatchQueue.global(qos: .userInitiated).async {
            let out = OCMacClient.shared.doctor()
            DispatchQueue.main.async {
                text = out
                stamp = Date()
                running = false
            }
        }
    }
}
