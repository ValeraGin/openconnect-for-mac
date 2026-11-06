import SwiftUI
import AppKit

struct SettingsWindow: View {
    static let width: CGFloat = 700
    static let height: CGFloat = 620
    @State private var page = SettingsPage.initial
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) { AppMark(size: 24); Text("OpenConnect").fontWeight(.semibold) }.padding(12)
                ForEach(SettingsPage.allCases) { item in
                    if item == .general || item == .about { Divider().padding(.vertical, 8) }
                    Button { page = item } label: {
                        HStack(spacing: 9) {
                            if item == .connection { AppMark(size: 17) } else { SettingsIcon(name: item.icon) }
                            Text(item.title).lineLimit(1)
                        }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 9)
                            .foregroundStyle(page == item ? Color.blue : .primary)
                            .background(page == item ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
                }
                Spacer()
            }.padding(.horizontal, 8).frame(width: 166).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            // One persistent editor owns the draft across all sidebar pages.
            ProfileEditorView(page: $page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(width: Self.width, height: Self.height).tint(.blue)
            .background(FixedSettingsWindow())
    }
}

// Preferences stay a small utility window, including the title-bar zoom action.
private struct FixedSettingsWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) { view.lockWindow() }

    final class Anchor: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.lockWindow() }
        }
        func lockWindow() {
            guard let window else { return }
            window.styleMask.remove(.resizable)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.collectionBehavior.insert(.fullScreenNone)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }
}
