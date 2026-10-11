import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let themeControl = NSSegmentedControl(labels: ["Black", "White"], trackingMode: .selectOne, target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 205),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Compile++ Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildInterface()
        refreshSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Appearance")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let explanation = NSTextField(wrappingLabelWithString: "Choose the color theme used by the editor, build output, and debugger panels.")
        explanation.font = .systemFont(ofSize: 12)
        explanation.textColor = .secondaryLabelColor

        themeControl.target = self
        themeControl.action = #selector(themeChanged(_:))
        themeControl.segmentStyle = .rounded

        let stack = NSStackView(views: [title, explanation, themeControl])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            themeControl.widthAnchor.constraint(equalToConstant: 240)
        ])
    }

    func refreshSelection() {
        let theme = ThemeStore.shared.current
        themeControl.selectedSegment = theme == .black ? 0 : 1
        window?.appearance = theme.appearance
    }

    @objc private func themeChanged(_ sender: NSSegmentedControl) {
        ThemeStore.shared.current = sender.selectedSegment == 1 ? .white : .black
        refreshSelection()
    }
}
