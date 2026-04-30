import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 220))
    let text = NSTextField(labelWithString: """
    HexQL provides a Quick Look preview extension that renders fallback previews as linked hex/ascii tables.

    Build and register this app, then use Finder Quick Look on files without a more specific preview.
    """)
    text.frame = NSRect(x: 28, y: 72, width: 464, height: 96)
    text.lineBreakMode = .byWordWrapping
    text.maximumNumberOfLines = 0
    contentView.addSubview(text)

    let window = NSWindow(
      contentRect: contentView.frame,
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.title = "HexQL"
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)
    self.window = window
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
