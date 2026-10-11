import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: IDEViewController?
    private var settingsWindowController: SettingsWindowController?
    private var terminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppearance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: .compilePlusPlusThemeDidChange,
            object: nil
        )

        let controller = IDEViewController()
        self.controller = controller

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Compile++"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 900, height: 600)
        window.contentViewController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        installMenus(for: controller)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            controller.openFile(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        if terminationPending { return .terminateLater }

        let waitingForVim = controller.saveAndCloseVim {
            self.terminationPending = false
            sender.reply(toApplicationShouldTerminate: true)
        }
        terminationPending = waitingForVim
        return waitingForVim ? .terminateLater : .terminateNow
    }

    private func installMenus(for controller: IDEViewController) {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Compile++", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Compile++", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        let newItem = fileMenu.addItem(withTitle: "New C++ File…", action: #selector(IDEViewController.newFile(_:)), keyEquivalent: "n")
        newItem.target = controller
        let openItem = fileMenu.addItem(withTitle: "Open C++ File…", action: #selector(IDEViewController.openFile(_:)), keyEquivalent: "o")
        openItem.target = controller

        let buildItem = NSMenuItem()
        mainMenu.addItem(buildItem)
        let buildMenu = NSMenu(title: "Build")
        buildItem.submenu = buildMenu
        let compileItem = buildMenu.addItem(withTitle: "Compile & Run", action: #selector(IDEViewController.compileAndRun(_:)), keyEquivalent: "b")
        compileItem.target = controller
        let debugItem = buildMenu.addItem(withTitle: "Show Debugger", action: #selector(IDEViewController.showDebugger(_:)), keyEquivalent: "d")
        debugItem.target = controller

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.refreshSelection()
        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyAppearance()
        settingsWindowController?.refreshSelection()
    }

    private func applyAppearance() {
        NSApp.appearance = ThemeStore.shared.current.appearance
    }
}
