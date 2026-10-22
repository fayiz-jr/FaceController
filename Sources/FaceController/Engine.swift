import AppKit
import Foundation

/// Turns face frames into game input.
final class Engine {
    private let config: Config
    private var active: [Bool]
    private var toggledOn: [Bool]
    private var lastRepeat: [Date]
    private var held = Set<String>()

    private(set) var paused = true
    private var pauseGestureSince: Date?
    private var pauseLatched = false

    /// Head yaw/pitch/roll while looking straight ahead, sampled on resume.
    private var baseline: (yaw: Float, pitch: Float, roll: Float)?
    private var calibration: [(Float, Float, Float)] = []

    /// Party slot FaceController last switched to (1-based). Reset to 1 on resume.
    private var slot = 1
    private var tilted = false

    var onStatus: ((String) -> Void)?

    init(config: Config) {
        self.config = config
        active = Array(repeating: false, count: config.actions.count)
        toggledOn = active
        lastRepeat = Array(repeating: .distantPast, count: config.actions.count)
    }

    func step(_ frame: FaceFrame?, dt: Double) {
        guard let frame else { return releaseAll() }
        watchPauseGesture(frame)
        guard !paused else { return }
        guard targetIsFrontmost() else { return releaseAll() }
        if baseline == nil {
            calibration.append((frame[.headYaw], frame[.headPitch], frame[.headRoll]))
            guard calibration.count >= 45 else { return }  // about 0.75 s
            let n = Float(calibration.count)
            baseline = (calibration.map(\.0).reduce(0, +) / n, calibration.map(\.1).reduce(0, +) / n,
                        calibration.map(\.2).reduce(0, +) / n)
            onStatus?("▶️  Playing (head centred, party slot 1)")
        }
        look(frame, dt: dt)
        switchCharacter(frame)
        for (i, action) in config.actions.enumerated() { apply(action, i, frame) }
    }

    func releaseAll() {
        for key in held { Input.set(key, down: false) }
        held.removeAll()
        for i in active.indices { active[i] = false; toggledOn[i] = false }
    }

    private func look(_ frame: FaceFrame, dt: Double) {
        guard let baseline else { return }
        func axis(_ v: Float) -> Double {
            let m = abs(v) - config.lookDeadZone
            return m > 0 ? Double(v > 0 ? m : -m) : 0
        }
        var dx = axis(frame[.headYaw] - baseline.yaw) * config.lookGainX * dt
        var dy = axis(frame[.headPitch] - baseline.pitch) * config.lookGainY * dt
        if config.invertX { dx = -dx }
        if config.invertY { dy = -dy }
        if dx != 0 || dy != 0 { Input.move(dx: dx, dy: dy) }
    }

    /// Ear towards the right shoulder: next party member; left: previous.
    private func switchCharacter(_ frame: FaceFrame) {
        guard let baseline, config.partySize > 1 else { return }
        var roll = frame[.headRoll] - baseline.roll
        if config.invertTilt { roll = -roll }
        if tilted {
            if abs(roll) < config.tiltOff { tilted = false }
            return
        }
        guard abs(roll) > config.tiltOn else { return }
        tilted = true
        slot = (slot - 1 + (roll > 0 ? 1 : config.partySize - 1)) % config.partySize + 1
        Input.tap("\(slot)")
        onStatus?("👥 Character \(slot)")
    }

    private func apply(_ a: Config.Action, _ i: Int, _ frame: FaceFrame) {
        let v = frame.value(a.trigger)
        let wasActive = active[i]
        let blocked = !wasActive && (a.unless ?? []).contains { frame.value($0) > 0.35 }
        let isActive = wasActive ? v > a.off : (v > a.on && !blocked)
        active[i] = isActive
        switch a.mode {
        case "tap":
            if isActive && !wasActive { Input.tap(a.key) }
        case "hold":
            if isActive != wasActive { setHeld(a.key, isActive) }
        case "toggle":
            if isActive && !wasActive {
                toggledOn[i].toggle()
                setHeld(a.key, toggledOn[i])
            }
        case "repeat":
            let every = Double(a.repeatMs ?? 250) / 1000
            if isActive && Date().timeIntervalSince(lastRepeat[i]) >= every {
                Input.tap(a.key)
                lastRepeat[i] = Date()
            }
        default: break
        }
    }

    private func setHeld(_ key: String, _ down: Bool) {
        Input.set(key, down: down)
        if down { held.insert(key) } else { held.remove(key) }
    }

    private func watchPauseGesture(_ frame: FaceFrame) {
        let doing = frame.value(config.pauseTrigger) > 0.5
        if !doing { pauseGestureSince = nil; pauseLatched = false; return }
        guard !pauseLatched else { return }
        let since = pauseGestureSince ?? Date()
        pauseGestureSince = since
        guard Date().timeIntervalSince(since) >= config.pauseHoldSeconds else { return }
        pauseLatched = true
        togglePause()
    }

    func togglePause() {
        paused.toggle()
        if paused {
            releaseAll()
            onStatus?("⏸️  Paused (hold \(config.pauseTrigger) to resume)")
        } else {
            recenter()
        }
    }

    /// Takes the current head position as straight ahead and the active
    /// character as slot 1.
    func recenter() {
        baseline = nil
        calibration.removeAll()
        slot = 1
        tilted = false
        onStatus?("🎯 Look straight ahead for a moment…")
    }

    var isCalibrating: Bool { !paused && baseline == nil }
    var currentSlot: Int { slot }

    func targetIsFrontmost() -> Bool {
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        return config.targetApps.isEmpty || config.targetApps.contains { name.localizedCaseInsensitiveContains($0) }
    }
}
