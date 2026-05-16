import Foundation
import IOKit

/// Reads real-time temperatures from the IOHIDEventSystem.
/// Works on Apple Silicon (M1/M2/M3) without special entitlements or root.
final class HIDThermalService {

    // MARK: - C function types (loaded via dlopen)
    private typealias CreateFn   = @convention(c) (CFAllocator?) -> OpaquePointer?
    private typealias SetMatchFn = @convention(c) (OpaquePointer, CFDictionary) -> Void
    private typealias CopySvcsFn = @convention(c) (OpaquePointer) -> CFArray?
    private typealias CopyEvtFn  = @convention(c) (OpaquePointer, Int64, Int32, Int64) -> OpaquePointer?
    private typealias GetFloatFn = @convention(c) (OpaquePointer, Int32) -> Double
    // Return type is CFTypeRef (a raw pointer), we handle retain manually
    private typealias CopyPropFn = @convention(c) (OpaquePointer, CFString) -> UnsafeRawPointer?

    private static let kEvtTypeTemperature: Int64 = 15
    private static let kFieldTempLevel: Int32      = Int32(15 << 16) | 0

    private let setMatchFn: SetMatchFn
    private let copySvcsFn: CopySvcsFn
    private let copyEvtFn:  CopyEvtFn
    private let getFloatFn: GetFloatFn
    private let copyPropFn: CopyPropFn
    private let client: OpaquePointer

    // MARK: - Sensor name substrings
    static let perfCoreSubstrings = ["pACC MTR", "p0 MTR", "p1 MTR"]
    static let effCoreSubstrings  = ["eACC MTR", "e0 MTR", "SOC MTR"]
    static let gpuSubstrings      = ["GPU MTR"]
    static let batterySubstrings  = ["gas gauge battery", "Battery"]
    static let socSubstrings      = ["PMGR SOC Die"]

    // MARK: - Init
    init?() {
        guard let lib = dlopen(
            "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_NOW)
        else { return nil }

        guard
            let sym1 = dlsym(lib, "IOHIDEventSystemClientCreate"),
            let sym2 = dlsym(lib, "IOHIDEventSystemClientSetMatching"),
            let sym3 = dlsym(lib, "IOHIDEventSystemClientCopyServices"),
            let sym4 = dlsym(lib, "IOHIDServiceClientCopyEvent"),
            let sym5 = dlsym(lib, "IOHIDEventGetFloatValue"),
            let sym6 = dlsym(lib, "IOHIDServiceClientCopyProperty")
        else { return nil }

        let createFn = unsafeBitCast(sym1, to: CreateFn.self)
        setMatchFn   = unsafeBitCast(sym2, to: SetMatchFn.self)
        copySvcsFn   = unsafeBitCast(sym3, to: CopySvcsFn.self)
        copyEvtFn    = unsafeBitCast(sym4, to: CopyEvtFn.self)
        getFloatFn   = unsafeBitCast(sym5, to: GetFloatFn.self)
        copyPropFn   = unsafeBitCast(sym6, to: CopyPropFn.self)

        guard let c = createFn(kCFAllocatorDefault) else { return nil }
        client = c

        let match: NSDictionary = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 0x0005]
        setMatchFn(client, match)
    }

    // MARK: - Public API

    func allReadings() -> [(name: String, temp: Double)] {
        guard let svcs = copySvcsFn(client) else { return [] }
        var results: [(name: String, temp: Double)] = []
        let count = CFArrayGetCount(svcs)
        for i in 0 ..< count {
            guard let raw = CFArrayGetValueAtIndex(svcs, i) else { continue }
            let svc = OpaquePointer(raw)

            // Safe property read — treat return as raw CFTypeRef
            let name: String
            if let propRaw = copyPropFn(svc, "Product" as CFString) {
                // IOHIDServiceClientCopyProperty returns +1 retained
                let cfObj = Unmanaged<CFTypeRef>.fromOpaque(propRaw).takeRetainedValue()
                name = (cfObj as? String) ?? "Sensor"
            } else {
                name = "Sensor"
            }

            guard let evtPtr = copyEvtFn(svc, Self.kEvtTypeTemperature, 0, 0) else { continue }
            let temp = getFloatFn(evtPtr, Self.kFieldTempLevel)

            if temp > 0 && temp < 120 {
                results.append((name: name, temp: temp))
            }
        }
        return results
    }

    func readings(matching substrings: [String]) -> [(name: String, temp: Double)] {
        allReadings().filter { r in substrings.contains(where: { r.name.contains($0) }) }
    }

    func averageTemp(matching substrings: [String]) -> Double? {
        let matched = readings(matching: substrings)
        guard !matched.isEmpty else { return nil }
        return matched.map(\.temp).reduce(0, +) / Double(matched.count)
    }

    func cpuTemperature() -> Double {
        if let t = averageTemp(matching: Self.perfCoreSubstrings), t > 0 { return t }
        if let t = averageTemp(matching: Self.effCoreSubstrings),  t > 0 { return t }
        return averageTemp(matching: Self.socSubstrings) ?? 0
    }

    func gpuTemperature()     -> Double { averageTemp(matching: Self.gpuSubstrings)     ?? 0 }
    func batteryTemperature() -> Double { averageTemp(matching: Self.batterySubstrings) ?? 0 }
}
