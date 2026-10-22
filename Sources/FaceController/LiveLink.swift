import Foundation

/// Face values streamed by Epic's Live Link Face app (ARKit mode): 52 ARKit
/// blendshapes followed by head yaw/pitch/roll and both eyes' yaw/pitch/roll.
enum Shape: Int, CaseIterable {
    case eyeBlinkLeft, eyeLookDownLeft, eyeLookInLeft, eyeLookOutLeft, eyeLookUpLeft
    case eyeSquintLeft, eyeWideLeft
    case eyeBlinkRight, eyeLookDownRight, eyeLookInRight, eyeLookOutRight, eyeLookUpRight
    case eyeSquintRight, eyeWideRight
    case jawForward, jawRight, jawLeft, jawOpen
    case mouthClose, mouthFunnel, mouthPucker, mouthRight, mouthLeft
    case mouthSmileLeft, mouthSmileRight, mouthFrownLeft, mouthFrownRight
    case mouthDimpleLeft, mouthDimpleRight, mouthStretchLeft, mouthStretchRight
    case mouthRollLower, mouthRollUpper, mouthShrugLower, mouthShrugUpper
    case mouthPressLeft, mouthPressRight, mouthLowerDownLeft, mouthLowerDownRight
    case mouthUpperUpLeft, mouthUpperUpRight
    case browDownLeft, browDownRight, browInnerUp, browOuterUpLeft, browOuterUpRight
    case cheekPuff, cheekSquintLeft, cheekSquintRight
    case noseSneerLeft, noseSneerRight, tongueOut
    case headYaw, headPitch, headRoll
    case leftEyeYaw, leftEyePitch, leftEyeRoll
    case rightEyeYaw, rightEyePitch, rightEyeRoll
}

struct FaceFrame {
    var values: [Float]
    subscript(_ s: Shape) -> Float { s.rawValue < values.count ? values[s.rawValue] : 0 }
}

enum LiveLink {
    /// Byte order of the floats, detected from the first packet that parses.
    static var bigEndian: Bool?

    /// Finds the blendshape block: a count byte followed by that many 32-bit
    /// floats. The layout around it has changed between app versions, so the
    /// block is located rather than read at a fixed offset.
    static func parse(_ data: Data) -> FaceFrame? {
        let bytes = [UInt8](data)
        guard bytes.count > 41 else { return nil }
        // Most packets end with the block; try that first, then scan.
        var starts: [Int] = []
        for n in [61, 52] where bytes.count >= 4 * n + 1 { starts.append(bytes.count - 4 * n - 1) }
        starts += Array(0..<max(0, bytes.count - 4 * 52 - 1))
        for p in starts {
            let n = Int(bytes[p])
            guard n == 61 || n == 52, p + 1 + 4 * n <= bytes.count else { continue }
            for be in bigEndian.map({ [$0] }) ?? [true, false] {
                if let v = floats(bytes, from: p + 1, count: n, bigEndian: be) {
                    bigEndian = be
                    return FaceFrame(values: v)
                }
            }
        }
        return nil
    }

    private static func floats(_ b: [UInt8], from: Int, count: Int, bigEndian: Bool) -> [Float]? {
        var out = [Float]()
        out.reserveCapacity(count)
        for i in 0..<count {
            let o = from + 4 * i
            var raw = UInt32(b[o]) << 24 | UInt32(b[o + 1]) << 16 | UInt32(b[o + 2]) << 8 | UInt32(b[o + 3])
            if !bigEndian { raw = raw.byteSwapped }
            let f = Float(bitPattern: raw)
            // Blendshapes are 0...1 and rotations are small; anything else
            // means this is not the block (or the wrong byte order).
            guard f.isFinite, abs(f) <= 3.5 else { return nil }
            out.append(f)
        }
        // Blendshapes are never negative.
        guard out.prefix(52).allSatisfy({ $0 >= -0.01 }) else { return nil }
        return out
    }
}
