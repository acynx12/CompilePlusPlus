import AppKit

@main
@MainActor
struct CompilePlusPlusApp {
    // NSApplication.delegate is not a strong reference. Keep the delegate for
    // the lifetime of the process so its window and controller stay alive.
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)

        application.delegate = appDelegate
        application.run()
    }
}
