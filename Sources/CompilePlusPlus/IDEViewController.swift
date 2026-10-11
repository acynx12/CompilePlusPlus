import AppKit
import SwiftTerm
import UniformTypeIdentifiers

@MainActor
private final class ThemePlaceholderView: NSView {
    private let symbolLabel: NSTextField
    private let titleLabel: NSTextField
    private let subtitleLabel: NSTextField

    init(symbol: String, title: String, subtitle: String) {
        symbolLabel = NSTextField(labelWithString: symbol)
        titleLabel = NSTextField(labelWithString: title)
        subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        super.init(frame: .zero)

        symbolLabel.font = .monospacedSystemFont(ofSize: 28, weight: .bold)
        symbolLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.alignment = .center

        let stack = NSStackView(views: [symbolLabel, titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -48)
        ])
        applyTheme(ThemeStore.shared.current)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme(_ theme: AppTheme) {
        let palette = ThemePalette.palette(for: theme)
        symbolLabel.textColor = palette.mutedText.withAlphaComponent(0.55)
        titleLabel.textColor = palette.secondaryText
        subtitleLabel.textColor = palette.mutedText
    }
}

@MainActor
final class IDEViewController: NSViewController, NSSplitViewDelegate, LocalProcessTerminalViewDelegate {
    private let editorPanel = PanelView(title: "Vim Editor", detail: "No file open")
    private let outputPanel = PanelView(title: "Build Output", detail: "Ready")
    private let debugPanel = PanelView(title: "GDB Debugger", detail: "gdb ./program")

    private let markLabel = NSTextField(labelWithString: "C++")
    private let appNameLabel = NSTextField(labelWithString: "Compile++")
    private let fileLabel = NSTextField(labelWithString: "Choose a C++ file to begin")
    private let debugToggle = NSButton()
    private let debugContainer = NSView()
    private let debugRegion = NSView()
    private let workspaceSplitView = NSSplitView()
    private let verticalSplitView = NSSplitView()
    private let collapsedDebuggerHeight: CGFloat = 0
    private var workspaceSplitRatio: CGFloat = 0.68
    private var debuggerSplitRatio: CGFloat = 0.38
    private var lastWorkspaceWidth: CGFloat = 0
    private var lastVerticalHeight: CGFloat = 0

    private var currentFile: URL?
    private var editorTerminal: LocalProcessTerminalView?
    private var outputTerminal: LocalProcessTerminalView?
    private var debugTerminal: LocalProcessTerminalView?
    private var debuggerIsVisible = false
    private var editorExitCompletions: [() -> Void] = []
    private var vimAcceptsCommands = false
    private var pendingVimSaveCommand = false

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        buildInterface()
        applyTheme(ThemeStore.shared.current)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: .compilePlusPlusThemeDidChange,
            object: nil
        )
    }

    private func buildInterface() {
        let toolbar = makeToolbar()

        workspaceSplitView.isVertical = true
        workspaceSplitView.dividerStyle = .thin
        workspaceSplitView.delegate = self
        workspaceSplitView.translatesAutoresizingMaskIntoConstraints = false
        workspaceSplitView.addArrangedSubview(editorPanel)
        workspaceSplitView.addArrangedSubview(outputPanel)

        let editorPlaceholder = makePlaceholder(
            symbol: "⌨",
            title: "Vim will open here",
            subtitle: "Choose a .cpp file, then edit it in a real terminal session."
        )
        editorPanel.replaceContent(with: editorPlaceholder)

        let outputPlaceholder = makePlaceholder(
            symbol: ">_",
            title: "Compile output appears here",
            subtitle: "Compile & Run invokes g++ with debug symbols, then runs the result."
        )
        outputPanel.replaceContent(with: outputPlaceholder)

        debugToggle.title = "▸  DEBUGGER  ·  Click to open GDB"
        debugToggle.font = .systemFont(ofSize: 12, weight: .semibold)
        debugToggle.alignment = .left
        debugToggle.isBordered = false
        debugToggle.contentTintColor = NSColor(srgbRed: 0.66, green: 0.72, blue: 0.82, alpha: 1)
        debugToggle.target = self
        debugToggle.action = #selector(toggleDebugger(_:))
        debugToggle.translatesAutoresizingMaskIntoConstraints = false

        debugContainer.translatesAutoresizingMaskIntoConstraints = false
        debugContainer.addSubview(debugPanel)
        debugPanel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            debugPanel.topAnchor.constraint(equalTo: debugContainer.topAnchor),
            debugPanel.leadingAnchor.constraint(equalTo: debugContainer.leadingAnchor),
            debugPanel.trailingAnchor.constraint(equalTo: debugContainer.trailingAnchor),
            debugPanel.bottomAnchor.constraint(equalTo: debugContainer.bottomAnchor)
        ])
        debugContainer.isHidden = true

        debugRegion.translatesAutoresizingMaskIntoConstraints = false
        debugRegion.addSubview(debugContainer)
        NSLayoutConstraint.activate([
            debugContainer.topAnchor.constraint(equalTo: debugRegion.topAnchor),
            debugContainer.leadingAnchor.constraint(equalTo: debugRegion.leadingAnchor),
            debugContainer.trailingAnchor.constraint(equalTo: debugRegion.trailingAnchor),
            debugContainer.bottomAnchor.constraint(equalTo: debugRegion.bottomAnchor)
        ])

        verticalSplitView.isVertical = false
        verticalSplitView.dividerStyle = .thin
        verticalSplitView.delegate = self
        verticalSplitView.translatesAutoresizingMaskIntoConstraints = false
        verticalSplitView.addArrangedSubview(workspaceSplitView)
        verticalSplitView.addArrangedSubview(debugRegion)

        view.addSubview(toolbar)
        view.addSubview(debugToggle)
        view.addSubview(verticalSplitView)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            toolbar.heightAnchor.constraint(equalToConstant: 48),

            debugToggle.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 6),
            debugToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            debugToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            debugToggle.heightAnchor.constraint(equalToConstant: 34),

            verticalSplitView.topAnchor.constraint(equalTo: debugToggle.bottomAnchor, constant: 6),
            verticalSplitView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            verticalSplitView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            verticalSplitView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14)
        ])
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let workspaceWidth = workspaceSplitView.bounds.width
        if workspaceWidth > 400 {
            if lastWorkspaceWidth == 0 || abs(workspaceWidth - lastWorkspaceWidth) > 0.5 {
                workspaceSplitView.setPosition(workspaceWidth * workspaceSplitRatio, ofDividerAt: 0)
            } else if let editor = workspaceSplitView.arrangedSubviews.first {
                workspaceSplitRatio = min(max(editor.frame.width / workspaceWidth, 0.25), 0.80)
            }
            lastWorkspaceWidth = workspaceWidth
        }

        let verticalHeight = verticalSplitView.bounds.height
        if verticalHeight > 300 {
            if debuggerIsVisible {
                if lastVerticalHeight == 0 || abs(verticalHeight - lastVerticalHeight) > 0.5 {
                    verticalSplitView.setPosition(verticalHeight * (1 - debuggerSplitRatio), ofDividerAt: 0)
                } else {
                    debuggerSplitRatio = min(max(debugRegion.frame.height / verticalHeight, 0.22), 0.65)
                }
            } else {
                verticalSplitView.setPosition(verticalHeight - collapsedDebuggerHeight, ofDividerAt: 0)
            }
            lastVerticalHeight = verticalHeight
        }
    }

    private func makeToolbar() -> NSView {
        let mark = markLabel
        mark.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        mark.textColor = NSColor(srgbRed: 0.26, green: 0.72, blue: 1.0, alpha: 1)
        mark.alignment = .center
        mark.wantsLayer = true
        mark.layer?.backgroundColor = NSColor(srgbRed: 0.08, green: 0.17, blue: 0.26, alpha: 1).cgColor
        mark.layer?.cornerRadius = 8
        mark.widthAnchor.constraint(equalToConstant: 48).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let appName = appNameLabel
        appName.font = .systemFont(ofSize: 19, weight: .bold)
        appName.textColor = NSColor.white.withAlphaComponent(0.92)

        fileLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        fileLabel.textColor = NSColor.white.withAlphaComponent(0.46)
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let newButton = makeButton(title: "New…", symbol: "doc.badge.plus", action: #selector(newFile(_:)))
        let openButton = makeButton(title: "Open…", symbol: "folder", action: #selector(openFile(_:)))
        let compileButton = makeButton(title: "Compile & Run", symbol: "play.fill", action: #selector(compileAndRun(_:)))
        compileButton.keyEquivalent = "\r"
        compileButton.bezelColor = NSColor(srgbRed: 0.05, green: 0.46, blue: 0.82, alpha: 1)

        let stack = NSStackView(views: [mark, appName, fileLabel, newButton, openButton, compileButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeButton(title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13, weight: .medium)
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            button.image = image
            button.imagePosition = .imageLeading
        }
        return button
    }

    private func makePlaceholder(symbol: String, title: String, subtitle: String) -> NSView {
        ThemePlaceholderView(symbol: symbol, title: title, subtitle: subtitle)
    }

    private func makeTerminal() -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(
            frame: .zero,
            font: .monospacedSystemFont(ofSize: 13, weight: .regular),
            options: TerminalOptions()
        )
        let palette = ThemePalette.palette(for: ThemeStore.shared.current)
        terminal.nativeBackgroundColor = palette.terminalBackground
        terminal.nativeForegroundColor = palette.terminalForeground
        terminal.caretColor = palette.accent
        terminal.bellStyle = .none
        terminal.layer?.backgroundColor = terminal.nativeBackgroundColor.cgColor
        terminal.processDelegate = self
        return terminal
    }

    @objc func openFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Open a C++ source file"
        panel.prompt = "Open in Vim"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "cpp") ?? .sourceCode,
            UTType(filenameExtension: "cc") ?? .sourceCode,
            UTType(filenameExtension: "cxx") ?? .sourceCode,
            UTType(filenameExtension: "c") ?? .sourceCode,
            UTType(filenameExtension: "h") ?? .sourceCode,
            UTType(filenameExtension: "hpp") ?? .sourceCode
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        if saveAndCloseVim(completion: { [weak self] in
            self?.openInVim(url)
        }) {
            editorPanel.detailLabel.stringValue = "Saving before opening " + url.lastPathComponent + "…"
        } else {
            openInVim(url)
        }
    }

    @objc func newFile(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.title = "Create a C++ source file"
        panel.prompt = "Create and Open in Vim"
        panel.nameFieldStringValue = "untitled.cpp"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [UTType(filenameExtension: "cpp") ?? .sourceCode]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let createAndOpen = { [weak self] in
            guard let self else { return }
            do {
                try Data().write(to: url, options: .atomic)
                self.openInVim(url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Compile++ could not create the file"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }

        if saveAndCloseVim(completion: createAndOpen) {
            editorPanel.detailLabel.stringValue = "Saving before creating " + url.lastPathComponent + "…"
        } else {
            createAndOpen()
        }
    }

    /// Sends the real Vim session Escape followed by `:wq`, then runs the
    /// completion after the process reports that it has exited.
    @discardableResult
    func saveAndCloseVim(completion: @escaping () -> Void) -> Bool {
        guard let terminal = editorTerminal else { return false }

        editorExitCompletions.append(completion)
        guard editorExitCompletions.count == 1 else { return true }

        if vimAcceptsCommands {
            sendSaveAndQuit(to: terminal)
        } else {
            pendingVimSaveCommand = true
        }
        return true
    }

    private func sendSaveAndQuit(to terminal: LocalProcessTerminalView) {
        pendingVimSaveCommand = false
        let saveAndQuit = [UInt8(0x1b)] + Array(":wq\r".utf8)
        terminal.send(data: saveAndQuit[...])
    }

    private func openInVim(_ url: URL) {
        editorTerminal?.terminate()
        outputTerminal?.terminate()
        debugTerminal?.terminate()
        outputTerminal = nil
        debugTerminal = nil

        currentFile = url.standardizedFileURL
        fileLabel.stringValue = currentFile!.path
        editorPanel.detailLabel.stringValue = currentFile!.lastPathComponent
        outputPanel.detailLabel.stringValue = "Ready to compile"
        debugPanel.detailLabel.stringValue = "gdb ./\(executableName(for: currentFile!))"

        if debuggerIsVisible {
            setDebuggerVisible(false)
        }

        outputPanel.replaceContent(with: makePlaceholder(
            symbol: ">_",
            title: "Compile output appears here",
            subtitle: "Compile & Run invokes g++ with debug symbols, then runs the result."
        ))

        launchVim(for: currentFile!)
    }

    private func launchVim(for fileToOpen: URL) {
        editorTerminal?.terminate()
        view.layoutSubtreeIfNeeded()
        let terminal = makeTerminal()
        editorTerminal = terminal
        vimAcceptsCommands = false
        pendingVimSaveCommand = false
        editorPanel.replaceContent(with: terminal)
        DispatchQueue.main.async { [weak self, weak terminal] in
            guard let self, let terminal, self.editorTerminal === terminal else { return }
            terminal.startProcess(
                executable: "/usr/bin/vim",
                args: [fileToOpen.lastPathComponent],
                execName: "vim",
                currentDirectory: fileToOpen.deletingLastPathComponent().path
            )
            // Give Vim time to switch the pseudo-terminal into raw mode. Until
            // then, a very fast Open/Quit action is queued instead of being
            // echoed by the terminal's initial line discipline.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak terminal] in
                guard let self, let terminal, self.editorTerminal === terminal else { return }
                self.vimAcceptsCommands = true
                self.view.window?.makeFirstResponder(terminal)
                if self.pendingVimSaveCommand {
                    self.sendSaveAndQuit(to: terminal)
                }
            }
        }
    }

    @objc func compileAndRun(_ sender: Any?) {
        guard let file = currentFile else {
            showOpenFileAlert(message: "Open a C++ file before compiling.")
            return
        }

        outputTerminal?.terminate()
        debugTerminal?.terminate()
        debugTerminal = nil

        let sourceName = file.lastPathComponent
        let outputName = executableName(for: file)
        let displayCommand = "g++ \(sourceName) -g -o \(outputName) && ./\(outputName)"
        let command = "g++ \(shellQuote(sourceName)) -g -o \(shellQuote(outputName)) && ./\(shellQuote(outputName))"

        let terminal = makeTerminal()
        outputTerminal = terminal
        outputPanel.detailLabel.stringValue = displayCommand
        outputPanel.replaceContent(with: terminal)
        terminal.feed(text: "$ \(displayCommand)\r\n\r\n")
        view.layoutSubtreeIfNeeded()
        DispatchQueue.main.async { [weak self, weak terminal] in
            guard let self, let terminal, self.outputTerminal === terminal else { return }
            terminal.startProcess(
                executable: "/bin/zsh",
                args: ["-l", "-c", command],
                execName: "zsh",
                currentDirectory: file.deletingLastPathComponent().path
            )
            self.view.window?.makeFirstResponder(terminal)
        }
    }

    @objc func showDebugger(_ sender: Any?) {
        if !debuggerIsVisible {
            setDebuggerVisible(true)
            launchDebuggerIfNeeded()
        } else if let terminal = debugTerminal {
            view.window?.makeFirstResponder(terminal)
        }
    }

    @objc private func toggleDebugger(_ sender: Any?) {
        setDebuggerVisible(!debuggerIsVisible)
        if debuggerIsVisible {
            launchDebuggerIfNeeded()
        }
    }

    private func setDebuggerVisible(_ visible: Bool) {
        let splitHeight = verticalSplitView.bounds.height
        if debuggerIsVisible, !visible, splitHeight > 0, debugRegion.frame.height > collapsedDebuggerHeight {
            debuggerSplitRatio = min(max(debugRegion.frame.height / splitHeight, 0.22), 0.65)
        }

        debuggerIsVisible = visible
        debugContainer.isHidden = !visible
        debugToggle.title = visible
            ? "▾  DEBUGGER  ·  GDB session"
            : "▸  DEBUGGER  ·  Click to open GDB"

        view.layoutSubtreeIfNeeded()
        if splitHeight > 300 {
            verticalSplitView.setPosition(
                visible ? splitHeight * (1 - debuggerSplitRatio) : splitHeight - collapsedDebuggerHeight,
                ofDividerAt: 0
            )
        }
    }

    private func launchDebuggerIfNeeded() {
        guard debugTerminal == nil else {
            if let terminal = debugTerminal { view.window?.makeFirstResponder(terminal) }
            return
        }
        guard let file = currentFile else {
            let placeholder = makePlaceholder(
                symbol: "(gdb)",
                title: "No program selected",
                subtitle: "Open and compile a C++ file first."
            )
            debugPanel.replaceContent(with: placeholder)
            return
        }

        let outputName = executableName(for: file)
        let terminal = makeTerminal()
        debugTerminal = terminal
        debugPanel.replaceContent(with: terminal)
        debugPanel.detailLabel.stringValue = "gdb ./\(outputName)"

        let debuggerCommand = """
        if command -v gdb >/dev/null 2>&1; then
          exec gdb ./\(shellQuote(outputName))
        else
          printf '\\nCompile++ could not find GDB.\\n\\nmacOS does not include GDB by default. Install it with:\\n  brew install gdb\\n\\nGDB also needs code signing on macOS.\\n'
          exec /bin/zsh -l
        fi
        """
        view.layoutSubtreeIfNeeded()
        DispatchQueue.main.async { [weak self, weak terminal] in
            guard let self, let terminal, self.debugTerminal === terminal else { return }
            terminal.startProcess(
                executable: "/bin/zsh",
                args: ["-l", "-c", debuggerCommand],
                execName: "zsh",
                currentDirectory: file.deletingLastPathComponent().path
            )
            self.view.window?.makeFirstResponder(terminal)
        }
    }

    private func executableName(for file: URL) -> String {
        let base = file.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "a" : base
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func showOpenFileAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Compile++"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open File…")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            openFile(nil)
        }
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyTheme(ThemeStore.shared.current)
    }

    private func applyTheme(_ theme: AppTheme) {
        let palette = ThemePalette.palette(for: theme)
        view.layer?.backgroundColor = palette.windowBackground.cgColor
        view.window?.appearance = theme.appearance

        markLabel.textColor = palette.accent
        markLabel.layer?.backgroundColor = theme == .black
            ? NSColor(srgbRed: 0.08, green: 0.17, blue: 0.26, alpha: 1).cgColor
            : NSColor(srgbRed: 0.82, green: 0.91, blue: 0.98, alpha: 1).cgColor
        appNameLabel.textColor = palette.primaryText
        fileLabel.textColor = palette.mutedText
        debugToggle.contentTintColor = palette.secondaryText

        for panel in [editorPanel, outputPanel, debugPanel] {
            panel.applyTheme(theme)
            (panel.contentView.subviews.first as? ThemePlaceholderView)?.applyTheme(theme)
        }

        for terminal in [editorTerminal, outputTerminal, debugTerminal].compactMap({ $0 }) {
            terminal.nativeBackgroundColor = palette.terminalBackground
            terminal.nativeForegroundColor = palette.terminalForeground
            terminal.caretColor = palette.accent
            terminal.layer?.backgroundColor = palette.terminalBackground.cgColor
            terminal.needsDisplay = true
        }
    }

    // MARK: - Terminal process lifecycle

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        if source === debugTerminal {
            debugTerminal = nil
            debugPanel.detailLabel.stringValue = "GDB session ended"
            setDebuggerVisible(false)
            if let editorTerminal {
                view.window?.makeFirstResponder(editorTerminal)
            }
            return
        }

        guard source === editorTerminal else { return }
        editorTerminal = nil
        vimAcceptsCommands = false
        pendingVimSaveCommand = false

        if !editorExitCompletions.isEmpty {
            let completions = editorExitCompletions
            editorExitCompletions.removeAll()
            DispatchQueue.main.async {
                completions.forEach { $0() }
            }
            return
        }

        showEmptyWorkspace()
    }

    private func showEmptyWorkspace() {
        currentFile = nil
        fileLabel.stringValue = "Choose a C++ file to begin"
        editorPanel.detailLabel.stringValue = "No file open"
        outputPanel.detailLabel.stringValue = "Ready"
        debugPanel.detailLabel.stringValue = "gdb ./program"

        let outputToStop = outputTerminal
        let debuggerToStop = debugTerminal
        outputTerminal = nil
        debugTerminal = nil
        outputToStop?.terminate()
        debuggerToStop?.terminate()

        if debuggerIsVisible {
            setDebuggerVisible(false)
        }

        editorPanel.replaceContent(with: makePlaceholder(
            symbol: "⌨",
            title: "Vim will open here",
            subtitle: "Create or open a .cpp file to begin."
        ))
        outputPanel.replaceContent(with: makePlaceholder(
            symbol: ">_",
            title: "Compile output appears here",
            subtitle: "Compile & Run invokes g++ with debug symbols, then runs the result."
        ))
    }

    // MARK: - Split view limits

    func splitView(
        _ splitView: NSSplitView,
        constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        if splitView === workspaceSplitView {
            return 260
        }
        if splitView === verticalSplitView {
            return debuggerIsVisible
                ? 220
                : splitView.bounds.height - collapsedDebuggerHeight
        }
        return proposedMinimumPosition
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        if splitView === workspaceSplitView {
            return max(260, splitView.bounds.width - 260)
        }
        if splitView === verticalSplitView {
            return debuggerIsVisible
                ? max(220, splitView.bounds.height - 180)
                : splitView.bounds.height - collapsedDebuggerHeight
        }
        return proposedMaximumPosition
    }
}
