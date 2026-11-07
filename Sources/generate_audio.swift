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
print("Generated six original in-app sound effects.")
