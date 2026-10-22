import AppKit

/// Menu bar item like AeroSpace's: shows the current workspace (and mode), and its menu lists
/// workspaces that have windows.
final class Tray {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func update(current: String, occupied: [String], mode: String, switchTo: @escaping (String) -> Void, quit: @escaping () -> Void) {
        item.button?.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        item.button?.title = mode == "main" ? current : "\(current) [\(mode)]"

        let menu = NSMenu()
        for name in occupied {
            let entry = MenuAction(name) { switchTo(name) }
            entry.state = name == current ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(MenuAction("Quit aether", key: "q", quit))
        item.menu = menu
    }
}

private final class MenuAction: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func run() { handler() }
}
