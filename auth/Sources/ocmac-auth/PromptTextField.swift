import AppKit

/// Modal authentication prompts must support editing even when the app menu
/// is not participating in key-equivalent dispatch. Let the native field editor
/// perform the paste so secure-field and pasteboard behavior stay with AppKit.
private func pasteInPrompt(_ field: NSTextField, event: NSEvent) -> Bool {
    guard event.type == .keyDown,
          event.modifierFlags.intersection([.command, .control, .option, .shift]) == [.command],
          event.charactersIgnoringModifiers?.lowercased() == "v",
          field.isEnabled, field.isEditable,
          let editor = field.currentEditor() as? NSTextView else { return false }
    editor.paste(nil)
    return true
}

class PromptTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        pasteInPrompt(self, event: event) || super.performKeyEquivalent(with: event)
    }
}

class PromptSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        pasteInPrompt(self, event: event) || super.performKeyEquivalent(with: event)
    }
}
