import AppKit

enum TeachDialog { static func brandIcon() -> NSImage { NSImage(size: .zero) } }

// Synthetic dispatch test: replace the native editor with a spy. This never
// invokes AppKit paste, reads a pasteboard, or inspects a user's password.
func L(_ text: String, _ args: CVarArg...) -> String { String(format: text, arguments: args) }
final class PasteSpy: NSTextView {
    var calls = 0
    override func paste(_ sender: Any?) { calls += 1 }
}
final class SecureProbe: PromptSecureTextField {
    let spy = PasteSpy()
    var editing = true
    override func currentEditor() -> NSText? { editing ? spy : nil }
}
final class PlainProbe: PromptTextField {
    let spy = PasteSpy()
    override func currentEditor() -> NSText? { spy }
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier
func event(_ key: String = "v", flags: NSEvent.ModifierFlags = .command) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                    windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key,
                    isARepeat: false, keyCode: 9)!
}
for secure in [true, false] {
    let prompt = PromptDialog(label: "Synthetic", profile: "Test", secure: secure)
    prompt.build()
    precondition(secure ? prompt.alert.accessoryView is PromptSecureTextField : prompt.alert.accessoryView is PromptTextField)
}
let secure = SecureProbe(frame: .zero)
precondition(secure.performKeyEquivalent(with: event()))
precondition(secure.spy.calls == 1)
// Caps Lock does not disable Cmd-V.
precondition(secure.performKeyEquivalent(with: event("V", flags: [.command, .capsLock])))
precondition(secure.spy.calls == 2)
for flags: NSEvent.ModifierFlags in [[], [.command, .shift], [.command, .option], [.command, .control]] {
    _ = secure.performKeyEquivalent(with: event(flags: flags))
}
_ = secure.performKeyEquivalent(with: event("x"))
precondition(secure.spy.calls == 2, "Other shortcuts must not paste")
secure.editing = false
_ = secure.performKeyEquivalent(with: event())
precondition(secure.spy.calls == 2, "Unfocused field must not paste")
secure.editing = true
secure.isEnabled = false
_ = secure.performKeyEquivalent(with: event())
precondition(secure.spy.calls == 2, "Disabled field must not paste")
let plain = PlainProbe(frame: .zero)
precondition(plain.performKeyEquivalent(with: event()))
precondition(plain.spy.calls == 1)
precondition(!app.isActive && NSWorkspace.shared.frontmostApplication?.processIdentifier == foreground)
print("PASS: password and code fields forward Cmd-V to editor; Caps Lock supported; other shortcuts, disabled and unfocused fields do not paste; no focus change. Synthetic editor; no clipboard access.")
