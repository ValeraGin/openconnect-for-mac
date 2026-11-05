import AppKit

/// The standalone auth executable has no nib/SwiftUI scene to install the
/// standard Edit menu. Nil targets keep editing in AppKit/WebKit's responder
/// chain, including secure fields; we never access the pasteboard ourselves.
enum EditingMenu {
    static func install(on app: NSApplication = .shared) {
        guard app.mainMenu == nil else { return }
        let main = NSMenu()
        let application = NSMenu()
        let applicationItem = NSMenuItem()
        applicationItem.submenu = application
        main.addItem(applicationItem)
        application.addItem(withTitle: L("Завершить"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let edit = NSMenu(title: L("Правка"))
        let editItem = NSMenuItem(title: L("Правка"), action: nil, keyEquivalent: "")
        editItem.submenu = edit
        main.addItem(editItem)
        edit.addItem(withTitle: L("Отменить действие"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("Повторить действие"), action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Вырезать"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Копировать"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Вставить"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Выделить всё"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        app.mainMenu = main
    }
}
