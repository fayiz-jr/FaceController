import Foundation

struct Config: Codable {
    struct Action: Codable {
        /// A shape name (see `Shape`), or "smile", "winkLeft" or "winkRight".
        var trigger: String
        /// Starts above `on`, ends below `off`, so it doesn't flicker at the edge.
        var on: Float
        var off: Float
        /// A key name (see `Input.keyCodes`), "leftClick" or "rightClick".
        var key: String
        /// "tap" once per gesture, "hold" while the gesture lasts,
        /// "toggle" on/off per gesture, or "repeat" taps while it lasts.
        var mode: String
        var repeatMs: Int?
        /// Gestures that drag this one along (puffed cheeks purse the lips,
        /// a stuck-out tongue opens the mouth); while any of them is above
        /// 0.35 this action doesn't start.
        var unless: [String]?
        var note: String?
    }

    var port: UInt16 = 11111
    /// Inputs are only sent while the frontmost app's name contains one of these.
    var targetApps: [String] = ["Genshin"]
    /// Pixels per second per unit of head turn past the dead zone.
    var lookGainX: Double = 2200
    var lookGainY: Double = 1400
    var lookDeadZone: Float = 0.04
    // Live Link Face reports yaw rising when the head turns left and pitch
    // rising when it tilts up; screen x grows rightwards and y downwards.
    var invertX = true
    var invertY = true
    /// Tilting the head (ear towards a shoulder) past this much head roll
    /// switches to the next or previous party member, pressing 1…partySize.
    var partySize = 4
    var tiltOn: Float = 0.25
    var tiltOff: Float = 0.12
    var invertTilt = false
    /// Hold this gesture to pause or resume everything.
    var pauseTrigger = "tongueOut"
    var pauseHoldSeconds = 0.8
    var actions: [Action] = [
        .init(trigger: "jawOpen", on: 0.45, off: 0.25, key: "space", mode: "tap", unless: ["tongueOut"], note: "open mouth: jump"),
        .init(trigger: "browInnerUp", on: 0.65, off: 0.4, key: "f", mode: "tap", unless: ["smile", "mouthPucker"], note: "raise eyebrows: interact / talk"),
        .init(trigger: "smile", on: 0.55, off: 0.35, key: "leftClick", mode: "repeat", repeatMs: 250, note: "smile: attack"),
        .init(trigger: "browDown", on: 0.45, off: 0.25, key: "leftClick", mode: "hold", unless: ["smile"], note: "angry eyebrows: hold attack (hold = charged attack)"),
        .init(trigger: "mouthPucker", on: 0.5, off: 0.3, key: "w", mode: "toggle", unless: ["cheekPuff"], note: "kissy face: walk forward on/off"),
        .init(trigger: "cheekPuff", on: 0.45, off: 0.25, key: "leftShift", mode: "hold", note: "puff cheeks: sprint"),
        .init(trigger: "winkLeft", on: 0.5, off: 0.3, key: "e", mode: "hold", note: "wink left: skill (hold the wink = hold skill)"),
        .init(trigger: "winkRight", on: 0.5, off: 0.3, key: "q", mode: "tap", note: "wink right: burst"),
    ]

    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/FaceController/config.json")

    /// Reads the config, writing the defaults on first run so they can be edited.
    static func load() -> Config {
        if let data = try? Data(contentsOf: url) {
            do { return try JSONDecoder().decode(Config.self, from: data) } catch {
                print("⚠️  \(url.path) is invalid (\(error)); using defaults")
                return Config()
            }
        }
        let config = Config()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(config).write(to: url)
        return config
    }
}

extension FaceFrame {
    func value(_ trigger: String) -> Float {
        switch trigger {
        case "smile": return (self[.mouthSmileLeft] + self[.mouthSmileRight]) / 2
        case "frown": return (self[.mouthFrownLeft] + self[.mouthFrownRight]) / 2
        case "browDown": return (self[.browDownLeft] + self[.browDownRight]) / 2
        // A wink is one eye closed and the other open; a normal blink cancels out.
        case "winkLeft": return self[.eyeBlinkLeft] - self[.eyeBlinkRight]
        case "winkRight": return self[.eyeBlinkRight] - self[.eyeBlinkLeft]
        default:
            guard let s = Shape.allCases.first(where: { "\($0)" == trigger }) else { return 0 }
            return self[s]
        }
    }
}
