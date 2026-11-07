import Foundation
import Darwin

let output = CommandLine.arguments.dropFirst().first ?? "Resources"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
let rate = 44_100

func u16(_ value: UInt16, into data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
}
func u32(_ value: UInt32, into data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}
func noise(_ n: Int) -> Double {
    let x = sin(Double(n) * 12.9898 + 78.233) * 43758.5453
    return (x - floor(x)) * 2 - 1
}
func write(_ name: String, duration: Double, sample: (Double, Int) -> Double) throws {
    let count = Int(Double(rate) * duration)
    var pcm = Data()
    pcm.reserveCapacity(count * 2)
    for i in 0..<count {
        let t = Double(i) / Double(rate)
        let value = max(-1.0, min(1.0, sample(t, i)))
        var signed = Int16(value * 32760)
        withUnsafeBytes(of: &signed) { pcm.append(contentsOf: $0) }
    }
    var wav = Data()
    wav.append(contentsOf: Array("RIFF".utf8))
    u32(UInt32(36 + pcm.count), into: &wav)
    wav.append(contentsOf: Array("WAVEfmt ".utf8))
    u32(16, into: &wav)
    u16(1, into: &wav)
    u16(1, into: &wav)
    u32(UInt32(rate), into: &wav)
    u32(UInt32(rate * 2), into: &wav)
    u16(2, into: &wav)
    u16(16, into: &wav)
    wav.append(contentsOf: Array("data".utf8))
    u32(UInt32(pcm.count), into: &wav)
    wav.append(pcm)
    try wav.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".wav"))
}

try write("tool_swing", duration: 0.22) { t, i in
    let env = pow(max(0, 1 - t / 0.22), 2)
    return (sin(2 * .pi * (150 - 75 * t) * t) * 0.18 + noise(i) * 0.20) * env
}
try write("device_tap", duration: 0.28) { t, i in
    let env = exp(-t * 18)
    return (sin(2 * .pi * 115 * t) * 0.42 + noise(i) * 0.20) * env
}
try write("device_thud", duration: 0.48) { t, i in
    let env = exp(-t * 9)
    return (sin(2 * .pi * (58 - 18 * t) * t) * 0.62 + noise(i) * 0.18) * env
}
try write("glass_tap", duration: 0.36) { t, i in
    let env = exp(-t * 12)
    return (sin(2 * .pi * 1320 * t) * 0.34 + sin(2 * .pi * 2180 * t) * 0.18 + noise(i) * 0.06) * env
}
try write("glass_shatter", duration: 1.15) { t, i in
    let burst = exp(-t * 3.1)
    let sparkle = sin(2 * .pi * (740 + 2100 * (t / 1.15)) * t) * 0.24
    let crackle = noise(i) * (0.35 * burst) * (noise(i / 330) > 0.30 ? 1 : 0.16)
    return (sparkle + crackle) * burst
}
try write("surface_scratch", duration: 0.62) { t, i in
    let env = sin(.pi * min(1, t / 0.62))
    let rasp = noise(i) * (0.22 + 0.18 * sin(2 * .pi * 19 * t))
    return rasp * env
}
try write("wood_knock", duration: 0.42) { t, i in
    let env = exp(-t * 13)
    return (sin(2 * .pi * 92 * t) * 0.42 + sin(2 * .pi * 164 * t) * 0.20 + noise(i) * 0.07) * env
}
try write("metal_clang", duration: 0.72) { t, i in
    let env = exp(-t * 4.4)
    return (sin(2 * .pi * 812 * t) * 0.22 + sin(2 * .pi * 1268 * t) * 0.16 +
            sin(2 * .pi * 1940 * t) * 0.10 + noise(i) * 0.035) * env
}
try write("plastic_click", duration: 0.16) { t, i in
    let env = exp(-t * 48)
    return (sin(2 * .pi * 780 * t) * 0.20 + noise(i) * 0.24) * env
}
try write("carpet_thump", duration: 0.38) { t, i in
    let env = exp(-t * 12)
    return (sin(2 * .pi * 54 * t) * 0.36 + noise(i) * 0.09) * env
}
try write("device_rattle", duration: 0.68) { t, i in
    let pulse = t.truncatingRemainder(dividingBy: 0.082)
    let env = exp(-t * 3.2) * exp(-pulse * 58)
    return (noise(i) * 0.24 + sin(2 * .pi * 680 * t) * 0.10) * env
}
try write("glass_crackle", duration: 0.44) { t, i in
    let env = exp(-t * 7.5)
    let gate = noise(i / 520) > 0.12 ? 1.0 : 0.12
    return (noise(i) * 0.30 + sin(2 * .pi * 2380 * t) * 0.11) * env * gate
}
try write("debris_scatter", duration: 0.92) { t, i in
    let pulse = abs(sin(2 * .pi * 8.5 * t))
    let env = exp(-t * 2.6) * pow(pulse, 7)
    return (noise(i) * 0.28 + sin(2 * .pi * (920 + 360 * t) * t) * 0.12) * env
}
print("Generated thirteen original in-app sound effects.")
