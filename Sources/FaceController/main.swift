import AppKit
import ApplicationServices
import Foundation

// FaceController: play games with your face. Epic's Live Link Face app on an iPhone
// (ARKit mode) streams face tracking over UDP; this turns it into keys and mouse.
//
//   FaceController           menu bar app
//   FaceController monitor   show live face values, to check gestures and tune thresholds
//   FaceController run       send game input from the terminal (starts paused)
//   FaceController raw       print the first packet as hex

let mode = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) ?? "app"
let config = Config.load()
let receiver = Receiver()

do { try receiver.start(port: config.port) } catch {
    let message = "Can't listen on UDP port \(config.port): \(error)"
    if mode == "app" {
        let alert = NSAlert()
        alert.messageText = "FaceController can't start"
        alert.informativeText = message + "\n\nIs FaceController already running?"
        alert.runModal()
    } else {
        print("❌ \(message)")
    }
    exit(1)
}

if mode == "app" {
    let app = NSApplication.shared
    let delegate = MenuBarController(config: config, receiver: receiver)
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
    exit(0)
}

// Terminal modes.

print("🎭 FaceController listening on UDP port \(config.port) (\(Receiver.localIP))")
print("   Config: \(Config.url.path)")

var dumped = false
if mode == "raw" {
    receiver.onPacket = { data in
        guard !dumped else { return }
        dumped = true
        print("\(data.count) bytes:")
        print(data.map { String(format: "%02x", $0) }.joined(separator: " "))
    }
}

let engine = Engine(config: config)
engine.onStatus = { print($0) }

if mode == "run" {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    if !AXIsProcessTrustedWithOptions(options) {
        print("⚠️  Needs Accessibility permission to press keys: System Settings → Privacy & Security → Accessibility.")
        print("   Allow the app you started FaceController from (e.g. Terminal), then run it again.")
    }
    for a in config.actions { print("   \(a.note ?? "\(a.trigger) → \(a.key)")") }
    print("   turn head: look around · tilt head right/left: next/previous character · hold \(config.pauseTrigger) \(config.pauseHoldSeconds)s: pause/resume")
    print("⏸️  Paused. Switch to the game and hold \(config.pauseTrigger) to start.")
}

var lastTick = Date()
var lastPrint = Date.distantPast
var warnedNoData = false
let started = Date()

let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in
    let now = Date()
    let dt = now.timeIntervalSince(lastTick)
    lastTick = now
    let fresh = receiver.fresh

    if fresh == nil, !warnedNoData, now.timeIntervalSince(started) > 8 {
        warnedNoData = true
        print(receiver.packets == 0
              ? "… no data yet. In Live Link Face: ARKit mode, target \(Receiver.localIP):\(config.port), same Wi-Fi, Live button on."
              : "… \(receiver.packets) packets received but none could be read. Run `FaceController raw` and share the output.")
    }
    if fresh != nil { warnedNoData = false }

    switch mode {
    case "run":
        engine.step(fresh, dt: dt)
    case "monitor":
        guard let f = fresh, now.timeIntervalSince(lastPrint) > 0.1 else { break }
        lastPrint = now
        func bar(_ v: Float) -> String {
            let n = max(0, min(8, Int((v * 8).rounded())))
            return String(repeating: "█", count: n) + String(repeating: "·", count: 8 - n)
        }
        let line = String(format: "yaw %+.2f pitch %+.2f roll %+.2f", f[.headYaw], f[.headPitch], f[.headRoll])
            + " │ mouth \(bar(f[.jawOpen])) brows \(bar(f[.browInnerUp])) angry \(bar(f.value("browDown")))"
            + " smile \(bar(f.value("smile"))) kiss \(bar(f[.mouthPucker])) puff \(bar(f[.cheekPuff]))"
            + " winkL \(bar(f.value("winkLeft"))) winkR \(bar(f.value("winkRight"))) tongue \(bar(f[.tongueOut]))"
        print("\r" + line, terminator: "")
        fflush(stdout)
    default:
        if dumped { exit(0) }
    }
}
RunLoop.main.add(timer, forMode: .common)

signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler {
    engine.releaseAll()
    print("\n👋 Bye")
    exit(0)
}
sigint.resume()

RunLoop.main.run()
