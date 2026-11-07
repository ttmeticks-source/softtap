import Foundation
import Darwin

let output = CommandLine.arguments.dropFirst().first ?? "Resources"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
let rate = 44_100

func u16(_ value: UInt16, into data: inout Data) {
    data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff))
}
func u32(_ value: UInt32, into data: inout Data) {
    data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff)); data.append(UInt8((value >> 24) & 0xff))
}
func noise(_ n: Int, _ seed: Int) -> Double {
    let x = sin(Double(n + seed * 7919) * 12.9898 + Double(seed) * 78.233) * 43758.5453
    return (x - floor(x)) * 2 - 1
}
func pulse(_ t: Double, _ center: Double, _ width: Double) -> Double {
    exp(-pow((t - center) / width, 2))
}
func write(_ name: String, duration: Double, seed: Int, sample: (Double, Int, Int) -> Double) throws {
    let count = Int(Double(rate) * duration)
    var pcm = Data()
    pcm.reserveCapacity(count * 2)
    for i in 0..<count {
        let t = Double(i) / Double(rate)
        let raw = sample(t, i, seed)
        let value = tanh(max(-2.0, min(2.0, raw)) * 1.12)
        var signed = Int16(max(-1, min(1, value)) * 32760)
        withUnsafeBytes(of: &signed) { pcm.append(contentsOf: $0) }
    }
    var wav = Data()
    wav.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count), into: &wav)
    wav.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16, into: &wav)
    u16(1, into: &wav); u16(1, into: &wav)
    u32(UInt32(rate), into: &wav); u32(UInt32(rate * 2), into: &wav)
    u16(2, into: &wav); u16(16, into: &wav)
    wav.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count), into: &wav)
    wav.append(pcm)
    try wav.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".wav"))
}

// Each sound is a small designed stack of a transient, body resonance and material
// modes. An alternate take is also emitted so repeated hits do not sound identical.
func pair(_ name: String, duration: Double, _ sample: @escaping (Double, Int, Int) -> Double) throws {
    try write(name, duration: duration, seed: 13, sample: sample)
    try write(name + "_alt", duration: duration, seed: 47, sample: sample)
}

try pair("tool_swing", duration: 0.30) { t, i, s in
    let air = noise(i, s) - noise(i - 38, s)
    let envelope = pow(max(0, 1 - t / 0.30), 1.6)
    let sweep = sin(2 * .pi * (92 + 36 * sin(t * 9)) * t)
    return (air * 0.095 + sweep * 0.075) * envelope * (0.65 + 0.35 * sin(.pi * t / 0.30))
}
try pair("device_tap", duration: 0.34) { t, i, s in
    let click = noise(i, s) * 0.42 * exp(-t * 175)
    let body = sin(2 * .pi * (365 + Double(s % 9) * 5) * t) * 0.19 * exp(-t * 24)
    let glassy = sin(2 * .pi * 1180 * t) * 0.07 * exp(-t * 34)
    return click + body + glassy
}
try pair("device_thud", duration: 0.62) { t, i, s in
    let transient = noise(i, s) * 0.34 * exp(-t * 72)
    let shell = sin(2 * .pi * (72 + Double(s % 7)) * t) * 0.40 * exp(-t * 7.2)
    let mid = sin(2 * .pi * 128 * t) * 0.18 * exp(-t * 11)
    let rattle = noise(i / 3, s + 5) * 0.07 * exp(-t * 15)
    return transient + shell + mid + rattle
}
try pair("glass_tap", duration: 0.48) { t, i, s in
    let strike = noise(i, s) * 0.22 * exp(-t * 95)
    let modes = sin(2 * .pi * 1280 * t) * 0.22 * exp(-t * 7.5)
        + sin(2 * .pi * 2137 * t) * 0.15 * exp(-t * 10)
        + sin(2 * .pi * 3190 * t) * 0.085 * exp(-t * 14)
    return strike + modes
}
try pair("glass_shatter", duration: 1.35) { t, i, s in
    let grains = noise(i, s) * (noise(i / 170, s + 2) > 0.20 ? 0.34 : 0.035) * exp(-t * 2.5)
    let high = sin(2 * .pi * (920 + 1850 * t) * t) * 0.12 * exp(-t * 2.8)
    let low = sin(2 * .pi * 118 * t) * 0.16 * exp(-t * 9)
    let ticks = (pulse(t, 0.08, 0.018) + pulse(t, 0.19, 0.026) + pulse(t, 0.42, 0.035) + pulse(t, 0.77, 0.045)) * noise(i / 5, s + 9) * 0.18
    return grains + high + low + ticks
}
try pair("surface_scratch", duration: 0.72) { t, i, s in
    let env = pow(max(0, sin(.pi * t / 0.72)), 0.7)
    let grit = noise(i, s) * 0.20 + (noise(i - 19, s) - noise(i - 41, s)) * 0.09
    let scrape = sin(2 * .pi * (540 + 180 * sin(t * 34)) * t) * 0.055
    return (grit + scrape) * env
}
try pair("wood_knock", duration: 0.54) { t, i, s in
    let attack = noise(i, s) * 0.26 * exp(-t * 95)
    let fundamental = sin(2 * .pi * (104 + Double(s % 6)) * t) * 0.36 * exp(-t * 10)
    let hollow = sin(2 * .pi * 188 * t) * 0.22 * exp(-t * 13)
    let upper = sin(2 * .pi * 316 * t) * 0.09 * exp(-t * 19)
    return attack + fundamental + hollow + upper
}
try pair("metal_clang", duration: 0.92) { t, i, s in
    let attack = noise(i, s) * 0.20 * exp(-t * 82)
    let ring = sin(2 * .pi * 742 * t) * 0.22 * exp(-t * 2.8)
        + sin(2 * .pi * 1193 * t) * 0.16 * exp(-t * 3.7)
        + sin(2 * .pi * 1871 * t) * 0.12 * exp(-t * 5.1)
        + sin(2 * .pi * 2639 * t) * 0.06 * exp(-t * 7.2)
    return attack + ring
}
try pair("plastic_click", duration: 0.23) { t, i, s in
    let snap = noise(i, s) * 0.46 * exp(-t * 150)
    let resonance = sin(2 * .pi * 890 * t) * 0.18 * exp(-t * 36)
        + sin(2 * .pi * 1510 * t) * 0.07 * exp(-t * 48)
    return snap + resonance
}
try pair("carpet_thump", duration: 0.52) { t, i, s in
    let muted = noise(i, s) * 0.13 * exp(-t * 22)
    let low = sin(2 * .pi * 48 * t) * 0.34 * exp(-t * 8.8)
    let body = sin(2 * .pi * 82 * t) * 0.12 * exp(-t * 13)
    return muted + low + body
}
try pair("device_rattle", duration: 0.82) { t, i, s in
    let interval = 0.065 + Double(s % 5) * 0.004
    let local = t.truncatingRemainder(dividingBy: interval)
    let envelope = exp(-t * 2.7) * exp(-local * (48 + Double(s % 8) * 2))
    return (noise(i, s) * 0.23 + sin(2 * .pi * (510 + Double(s % 90)) * t) * 0.09) * envelope
}
try pair("glass_crackle", duration: 0.56) { t, i, s in
    let gate = noise(i / 330, s + 3) > 0.06 ? 1.0 : 0.08
    let fizz = noise(i, s) * 0.27 * exp(-t * 6.5) * gate
    let brittle = sin(2 * .pi * 2470 * t) * 0.10 * exp(-t * 11)
    let ticks = pulse(t, 0.07, 0.012) + pulse(t, 0.16, 0.016) + pulse(t, 0.31, 0.022)
    return fizz + brittle + ticks * noise(i / 7, s + 11) * 0.13
}
try pair("debris_scatter", duration: 1.10) { t, i, s in
    let grains = noise(i, s) * 0.22 * exp(-t * 2.3) * pow(abs(sin(2 * .pi * (7.4 + Double(s % 4) * 0.4) * t)), 8)
    let tinkle = sin(2 * .pi * (740 + 420 * t) * t) * 0.10 * exp(-t * 3.1)
    return grains + tinkle
}

try pair("sledgehammer_impact", duration: 0.82) { t, i, s in
    let crack = noise(i, s) * 0.42 * exp(-t * 88)
    let body = sin(2 * .pi * 58 * t) * 0.44 * exp(-t * 6.8)
        + sin(2 * .pi * 116 * t) * 0.24 * exp(-t * 9.5)
        + sin(2 * .pi * 244 * t) * 0.08 * exp(-t * 15)
    return crack + body
}
try pair("crowbar_creak", duration: 0.64) { t, i, s in
    let strain = sin(2 * .pi * (190 + 70 * sin(t * 17)) * t) * 0.15
    let metalTicks = noise(i, s) * 0.12 * (pulse(t, 0.12, 0.025) + pulse(t, 0.38, 0.04))
    return (strain + metalTicks) * exp(-t * 1.8)
}
try pair("drill_whirr", duration: 0.72) { t, i, s in
    let spin = sin(2 * .pi * (145 + 28 * sin(t * 22)) * t) * 0.18
        + sin(2 * .pi * (290 + 54 * sin(t * 22)) * t) * 0.08
    let motor = noise(i, s) * 0.055
    return (spin + motor) * min(1, t * 18) * exp(-t * 0.55)
}
try pair("saw_whine", duration: 0.76) { t, i, s in
    let carrier = sin(2 * .pi * (760 + 180 * sin(t * 28)) * t) * 0.15
    let rasp = (noise(i, s) - noise(i - 26, s)) * 0.10
    return (carrier + rasp) * min(1, t * 16) * exp(-t * 0.65)
}
try pair("fire_roar", duration: 1.15) { t, i, s in
    let low = sin(2 * .pi * (74 + 16 * sin(t * 5)) * t) * 0.13
    let turbulent = noise(i, s) * 0.20 * (0.65 + 0.35 * sin(t * 31))
    let hiss = (noise(i - 33, s) - noise(i - 97, s)) * 0.08
    return (low + turbulent + hiss) * (0.78 + 0.22 * sin(t * 9))
}
try pair("water_spray", duration: 0.68) { t, i, s in
    let spray = noise(i, s) * 0.19 * exp(-t * 1.5)
    let droplets = noise(i / 90, s + 4) > 0.15 ? 0.12 : 0.025
    let hiss = (noise(i - 15, s) - noise(i - 58, s)) * 0.09
    return (spray * droplets + hiss) * exp(-t * 1.1)
}
try pair("steam_hiss", duration: 0.90) { t, i, s in
    let broadband = (noise(i, s) - noise(i - 64, s)) * 0.18
    let pressure = sin(2 * .pi * 410 * t) * 0.025
    return (broadband + pressure) * exp(-t * 2.2) * min(1, t * 30)
}

print("Generated twenty layered material and tool effects, with alternate randomized takes.")
