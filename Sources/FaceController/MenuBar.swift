import AppKit
import ApplicationServices
import ServiceManagement

/// The 🎭 menu bar item: start/pause, recenter, a live face preview and settings.
final class MenuBarController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let config: Config
    private let receiver: Receiver
    private let engine: Engine
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let statusLine = NSMenuItem()
    private let toggleItem = NSMenuItem()
    private let preview = FacePreviewView()
    private var lastTick = Date()
    private var lastState = ""

    init(config: Config, receiver: Receiver) {
        self.config = config
        self.receiver = receiver
        engine = Engine(config: config)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        statusItem.menu = menu
        engine.onStatus = { [weak self] _ in self?.refresh() }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) { engine.releaseAll() }

    private func tick() {
        let now = Date()
        engine.step(receiver.fresh, dt: now.timeIntervalSince(lastTick))
        lastTick = now
        refresh()
    }

    // MARK: State

    private var state: (text: String, symbol: String) {
        if !AXIsProcessTrusted() { return ("Needs Accessibility permission", "exclamationmark.triangle") }
        guard receiver.fresh != nil else {
            return (receiver.packets == 0 ? "Waiting for iPhone…" : "iPhone stopped sending", "iphone.slash")
        }
        if engine.paused { return ("Paused · hold tongue out to start", "face.dashed") }
        if engine.isCalibrating { return ("Look straight ahead…", "scope") }
        if !engine.targetIsFrontmost() { return ("Playing · waiting for Genshin", "face.smiling") }
        return ("Playing · character \(engine.currentSlot)", "face.smiling.inverse")
    }

    private func refresh() {
        let (text, symbol) = state
        if text != lastState {
            lastState = text
            statusLine.title = text
            toggleItem.title = engine.paused ? "Start" : "Pause"
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "FaceController")
            image?.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.toolTip = "FaceController: \(text)"
        }
        if menu.highlightedItem != nil || preview.window?.isVisible == true {
            preview.face = receiver.fresh
            preview.needsDisplay = true
        }
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        toggleItem.action = #selector(togglePause)
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(item("Recenter Head", #selector(recenter)))
        menu.addItem(.separator())

        let previewItem = NSMenuItem()
        previewItem.view = preview
        menu.addItem(previewItem)
        menu.addItem(.separator())

        let controls = NSMenuItem(title: "Controls", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let lines = config.actions.map { $0.note ?? "\($0.trigger) → \($0.key)" } + [
            "turn head: look around",
            "tilt head right / left: next / previous character",
            "hold tongue out: pause / resume",
        ]
        for line in lines {
            let i = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            i.isEnabled = false
            sub.addItem(i)
        }
        controls.submenu = sub
        menu.addItem(controls)

        let setup = NSMenuItem(title: "iPhone Setup", action: nil, keyEquivalent: "")
        let setupMenu = NSMenu()
        for line in ["Live Link Face app → Live Link (ARKit)",
                     "Target: \(Receiver.localIP) · port \(config.port)",
                     "Stream Head Rotation: on · same Wi-Fi · LIVE"] {
            let i = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            i.isEnabled = false
            setupMenu.addItem(i)
        }
        setup.submenu = setupMenu
        menu.addItem(setup)

        menu.addItem(item("Edit Settings…", #selector(editSettings)))
        let login = item("Open at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Quit FaceController", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    func menuWillOpen(_ menu: NSMenu) {
        preview.face = receiver.fresh
        preview.needsDisplay = true
    }

    @objc private func togglePause() { engine.togglePause(); refresh() }
    @objc private func recenter() { engine.recenter(); refresh() }

    @objc private func editSettings() {
        NSWorkspace.shared.open(Config.url)
        let alert = NSAlert()
        alert.messageText = "Settings opened"
        alert.informativeText = "After saving your changes, quit and reopen FaceController to apply them. Delete the file to go back to the defaults."
        alert.runModal()
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

/// Live bars for the gestures FaceController uses.
final class FacePreviewView: NSView {
    var face: FaceFrame?

    private let rows: [(String, String)] = [
        ("😮 Jump", "jawOpen"), ("🤨 Interact", "browInnerUp"), ("😤 Charged", "browDown"),
        ("😄 Attack", "smile"), ("😗 Walk", "mouthPucker"), ("🐡 Sprint", "cheekPuff"),
        ("😉 Skill", "winkLeft"), ("😉 Burst", "winkRight"), ("😛 Pause", "tongueOut"),
    ]

    init() { super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 9 * 18 + 34)) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.systemFont(ofSize: 12)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        guard let f = face else {
            ("No face data" as NSString).draw(at: NSPoint(x: 20, y: bounds.height - 24), withAttributes: attrs)
            return
        }
        let head = String(format: "Head  turn %+.2f   tilt-up %+.2f   lean %+.2f",
                          f[.headYaw], f[.headPitch], f[.headRoll])
        (head as NSString).draw(at: NSPoint(x: 20, y: bounds.height - 22), withAttributes: attrs)
        for (i, (label, trigger)) in rows.enumerated() {
            let y = bounds.height - 44 - CGFloat(i) * 18
            (label as NSString).draw(at: NSPoint(x: 20, y: y), withAttributes: attrs)
            let track = NSRect(x: 120, y: y + 4, width: 120, height: 8)
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: track, xRadius: 4, yRadius: 4).fill()
            let v = CGFloat(max(0, min(1, f.value(trigger))))
            var fill = track
            fill.size.width *= v
            (v > 0.5 ? NSColor.systemGreen : NSColor.controlAccentColor).setFill()
            NSBezierPath(roundedRect: fill, xRadius: 4, yRadius: 4).fill()
        }
    }
}
