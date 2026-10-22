import CoreGraphics
import Foundation

/// Synthetic keyboard and mouse input, as a hardware keyboard and mouse would send it.
enum Input {
    static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "o": 31, "u": 32, "i": 34, "p": 35,
        "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "tab": 48, "space": 49, "escape": 53, "leftShift": 56, "leftAlt": 58, "leftControl": 59,
        "return": 36,
    ]
    static let mouseButtons: Set<String> = ["leftClick", "rightClick"]

    static func isValid(_ name: String) -> Bool { keyCodes[name] != nil || mouseButtons.contains(name) }

    private static let source = CGEventSource(stateID: .hidSystemState)

    static func set(_ name: String, down: Bool) {
        if let code = keyCodes[name] {
            CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)?.post(tap: .cghidEventTap)
        } else if name == "leftClick" || name == "rightClick" {
            let left = name == "leftClick"
            let type: CGEventType = left ? (down ? .leftMouseDown : .leftMouseUp) : (down ? .rightMouseDown : .rightMouseUp)
            CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: cursor(),
                    mouseButton: left ? .left : .right)?.post(tap: .cghidEventTap)
        }
    }

    static func tap(_ name: String) {
        set(name, down: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { set(name, down: false) }
    }

    /// Relative mouse motion. Games that capture the cursor read the deltas;
    /// elsewhere the pointer itself moves.
    static func move(dx: Double, dy: Double) {
        let p = cursor()
        var target = CGPoint(x: p.x + dx, y: p.y + dy)
        // At a screen edge the window server stops the pointer and the motion
        // with it, so the camera would stop turning. Keep it away from edges.
        let screen = CGDisplayBounds(CGMainDisplayID()).insetBy(dx: 80, dy: 80)
        if !screen.contains(target) { target = CGPoint(x: screen.midX, y: screen.midY) }
        guard let e = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                              mouseCursorPosition: target, mouseButton: .left) else { return }
        e.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx.rounded()))
        e.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy.rounded()))
        e.post(tap: .cghidEventTap)
    }

    private static func cursor() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
}
