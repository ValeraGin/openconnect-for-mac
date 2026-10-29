import AppKit
import SwiftUI

/// Original Lucide SVGs, pinned with their licenses in Resources/Lucide.
struct Lucide: View {
    let name: String
    var size: CGFloat = 18
    private static var images: [String: NSImage] = [:]
    private var image: NSImage {
        if let cached = Self.images[name] { return cached }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Lucide/\(name).svg"),
              let image = NSImage(contentsOf: url) else { preconditionFailure("Missing Lucide icon: \(name)") }
        image.isTemplate = true
        Self.images[name] = image
        return image
    }
    var body: some View {
        Image(nsImage: image).resizable().renderingMode(.template)
            .aspectRatio(contentMode: .fit).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct IconLabel: View {
    let title: String
    let icon: String
    var body: some View { HStack(spacing: 8) { Lucide(name: icon); Text(title) } }
}

/// NSTextField guarantees a single line, including for long values and paste.
/// Long values scroll while editing; the tooltip exposes the full value.
struct SingleLineInput: NSViewRepresentable {
    @Binding var text: String
    var label: String
    var placeholder = ""
    func makeNSView(context: Context) -> NSTextField {
        let input = NSTextField(string: text)
        input.font = .systemFont(ofSize: 13)
        input.isBezeled = true
        input.bezelStyle = .roundedBezel
        input.cell?.usesSingleLineMode = true
        input.cell?.isScrollable = true
        input.lineBreakMode = .byTruncatingMiddle
        input.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        input.delegate = context.coordinator
        return input
    }
    func updateNSView(_ input: NSTextField, context: Context) {
        context.coordinator.parent = self
        if input.stringValue != text { input.stringValue = text }
        input.placeholderString = placeholder
        input.toolTip = text
        input.setAccessibilityLabel(label)
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SingleLineInput
        init(_ parent: SingleLineInput) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let input = notification.object as? NSTextField else { return }
            let clean = DemoModel.singleLine(input.stringValue)
            if clean != input.stringValue { input.stringValue = clean }
            parent.text = clean
        }
    }
}

enum LabColor {
    static let accent = Color.blue
    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let failure = Color(nsColor: .systemRed)
}

/// Reuse the production brand asset without redrawing or recoloring it.
struct BrandMark: View {
    var size: CGFloat = 32
    var body: some View {
        Image(nsImage: NSImage(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("mark.svg"))!)
            .resizable().aspectRatio(contentMode: .fit).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
