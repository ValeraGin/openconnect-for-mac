import AppKit

func L(_ text: String) -> String { text }
final class EditingTarget: NSObject {
    var actions: [String] = []
    @objc func paste(_ sender: Any?) { actions.append("paste") }
    @objc func copy(_ sender: Any?) { actions.append("copy") }
    @objc func cut(_ sender: Any?) { actions.append("cut") }
    @objc func selectAll(_ sender: Any?) { actions.append("selectAll") }
    @objc func undo(_ sender: Any?) { actions.append("undo") }
    @objc func redo(_ sender: Any?) { actions.append("redo") }
}
setbuf(stdout, nil)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier
let target = EditingTarget()
func event(_ key: String, _ modifiers: NSEvent.ModifierFlags = [.command]) -> NSEvent {
    let characters = modifiers.contains(.shift) ? key.uppercased() : key
    return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                    windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                    isARepeat: false, keyCode: ["a": UInt16(0), "c": 8, "x": 7, "v": 9, "z": 6][key]!)!
}
precondition(app.mainMenu?.performKeyEquivalent(with: event("v")) != true)
EditingMenu.install(on: app)
let menu = app.mainMenu!
let edit = menu.items.compactMap(\.submenu).first { $0.title == "Правка" }!
for item in edit.items where !item.isSeparatorItem {
    precondition(item.target == nil, "Production commands must use the responder chain")
    item.target = target
}
let checks: [(String, NSEvent.ModifierFlags, String)] = [
    ("v", [.command], "paste"), ("a", [.command], "selectAll"),
    ("c", [.command], "copy"), ("x", [.command], "cut"),
    ("z", [.command], "undo"), ("z", [.command, .shift], "redo")
]
for (key, modifiers, expected) in checks {
    let handled = menu.performKeyEquivalent(with: event(key, modifiers))
    print("\(expected): handled=\(handled) actual=\(target.actions.last ?? "none")")
    precondition(handled, "Shortcut was not handled")
    precondition(target.actions.last == expected, "Shortcut went to the wrong action")
}
let before = target.actions.count
precondition(!menu.performKeyEquivalent(with: event("v", [.command, .option])))
precondition(target.actions.count == before)
EditingMenu.install(on: app)
precondition(app.mainMenu === menu, "Installation must not replace an existing menu")
precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier == foreground)
precondition(!app.isActive)
print("PASS: Cmd-V/A/C/X/Z/Shift-Z dispatch through AppKit menu; unrelated shortcut untouched; existing menu preserved; no activation. Clipboard never accessed.")
