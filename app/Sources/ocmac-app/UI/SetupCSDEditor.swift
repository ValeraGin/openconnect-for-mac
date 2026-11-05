import AppKit
import SwiftUI

struct SetupCSDEditor: View {
    @ObservedObject var flow: SetupFlow
    @Environment(\.dismiss) private var dismiss
    @State private var usePath: Bool
    @State private var script: String
    @State private var path: String
    @State private var fileError: String?

    init(flow: SetupFlow) {
        self.flow = flow
        _usePath = State(initialValue: !flow.doc.csdWrapper.isEmpty)
        _path = State(initialValue: flow.doc.csdWrapper)
        _script = State(initialValue: Data(base64Encoded: flow.doc.csdScriptBase64)
            .flatMap { String(data: $0, encoding: .utf8) } ?? "")
    }

    private var issue: String? {
        if usePath { return nil }
        return script.isEmpty ? nil : ProfileDoc.csdScriptIssue(Data(script.utf8).base64EncodedString())
    }
    private var empty: Bool { usePath ? path.trimmed.isEmpty : script.isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Проверка устройства · CSD")).font(.headline)
            Text(L("Добавьте скрипт, предоставленный для вашего VPN. Он запускается при проверке устройства перед входом."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker(L("Источник скрипта"), selection: $usePath) {
                Text(L("Текст скрипта")).tag(false)
                Text(L("Путь к скрипту")).tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            if usePath {
                TextField(L("Путь к скрипту"), text: $path, prompt: Text("/path/to/csd-wrapper.sh"))
                    .textFieldStyle(.roundedBorder)
                Button(L("Выбрать файл…")) { chooseFile() }
                Text(L("Файл должен оставаться по этому пути и быть исполняемым."))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                TextEditor(text: $script).font(.system(.body, design: .monospaced))
                    .accessibilityLabel(L("Текст CSD-скрипта"))
                    .border(Color(nsColor: .separatorColor)).frame(minHeight: 110)
                HStack {
                    Button(L("Загрузить из файла…")) { chooseFile() }
                    Text(L("UTF-8 · начинается с #! · до 256 КиБ"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = fileError ?? issue ?? flow.note {
                ScrollView { Text(error).font(.caption).foregroundStyle(Palette.bad).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 50)
            }
            Divider()
            HStack {
                Button(L("Отмена")) { dismiss() }.keyboardShortcut(.cancelAction).disabled(flow.busy)
                Spacer()
                if flow.busy { ProgressView().controlSize(.small) }
                Button(L("Сохранить")) {
                    fileError = nil
                    flow.saveCSD(wrapper: usePath ? path : "", script: usePath ? "" : script) { saved in
                        if saved { StatusStore.shared.dismissNote(); dismiss() }
                    }
                }.keyboardShortcut(.defaultAction).disabled(empty || issue != nil || flow.busy || flow.checking)
            }
        }.padding(20).frame(width: 520, height: 420)
            .disabled(flow.busy)
            .onChange(of: script) { _, _ in fileError = nil }
            .onChange(of: path) { _, _ in fileError = nil }
            .onChange(of: usePath) { _, _ in fileError = nil }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if usePath { path = url.path; fileError = nil; return }
            do {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: 256 * 1024 + 1) ?? Data()
                if let why = ProfileDoc.csdScriptIssue(data.base64EncodedString()) { fileError = why; return }
                script = String(decoding: data, as: UTF8.self); fileError = nil
            } catch { fileError = L("Не удалось прочитать CSD-скрипт: %@", error.localizedDescription) }
        }
    }
}
