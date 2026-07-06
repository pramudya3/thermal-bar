import Foundation
import IOKit

/// A service to interact with the Apple System Management Controller (SMC).
/// Optimized for Apple Silicon (M1/M2/M3) and Intel Macs.
class SMCService {
    private var connection: io_connect_t = 0

    // SMC Constants
    private static let KERNEL_INDEX_SMC: UInt32 = 2
    private static let SMC_CMD_READ_KEYINFO: UInt8 = 9
    private static let SMC_CMD_READ_BYTES: UInt8 = 5

    // --- CPU Keys ---
    // Apple Silicon efficiency cores (lower power cluster)
    static let efficiencyCoreKeys: [(key: String, label: String)] = [
        ("Te0T", "Efficiency Cores Package"),
        ("Te0L", "Efficiency Cores Package"),
        ("Te0P", "Efficiency Cores Package"),
        ("Te0S", "Efficiency Cores Package"),
        ("Te01", "Efficiency Cores Package"),
        ("Tp01", "Efficiency Cores Package"),
        ("Tp0d", "Efficiency Cores Package"),
        ("Tp0h", "Efficiency Cores Package"),
    ]

    // Apple Silicon performance cores (higher power cluster) + Intel CPU
    static let performanceCoreKeys: [(key: String, label: String)] = [
        ("Tp09", "Performance Cores Package"),
        ("Tp05", "Performance Cores Package"),
        ("Tp0L", "Performance Cores Package"),
        ("Tp0T", "Performance Cores Package"),
        ("Tp0P", "Performance Cores Package"),
        ("Tp0k", "Performance Cores Package"),
        ("Tp0j", "Performance Cores Package"),
        ("TC0P", "CPU Package"),  // Intel
        ("TC0D", "CPU Die"),      // Intel
        ("TC0E", "CPU IA"),       // Intel
    ]

    // --- GPU Keys ---
    static let gpuKeys: [(key: String, label: String)] = [
        ("Tg05", "GPU"),
        ("Tg0D", "GPU"),
        ("Tg0L", "GPU"),
        ("Tg0P", "GPU"),
        ("Tg0T", "GPU"),
        ("Tg0j", "GPU"),
        ("Tg0k", "GPU"),
        ("TG0P", "GPU"), // Intel
        ("TG0D", "GPU"),
    ]

    // --- Battery Keys ---
    static let batteryKeys: [(key: String, label: String)] = [
        ("TB1T", "Battery Gas Gauge"),
        ("TB0T", "Battery"),
        ("TB2T", "Battery Management Unit"),
        ("TBXT", "Battery Proximity"),
        ("TB0S", "Battery"),
        ("TB1S", "Battery"),
    ]

    // SMC struct matching exact C layout from Apple's PowerManagement source.
    // Total size must be 80 bytes for IOConnectCallStructMethod to succeed.
    // A compile‑time check ensures we stay in sync with the kernel ABI.
    private static let smcStructSizeExpected = 80

    struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: (UInt8, UInt8, UInt8, UInt8) = (0,0,0,0) // 4 bytes, NOT 1!
        var release: UInt16 = 0
    } // 9 bytes

    struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    } // 16 bytes

    struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    } // 9 bytes

    struct SMCParamStruct {
        var key: UInt32 = 0          // offset 0,  4 bytes
        var vers = SMCVersion()      // offset 4,  9 bytes → ends at 13
        // 3 bytes implicit padding → pLimit aligns to 16
        var pLimit = SMCPLimitData() // offset 16, 16 bytes → ends at 32
        var keyInfo = SMCKeyInfoData() // offset 32, 9 bytes → ends at 41
        var result: UInt8 = 0        // offset 41
        var status: UInt8 = 0        // offset 42
        var data8: UInt8 = 0         // offset 43
        // 1 byte implicit padding → data32 aligns to 44
        var data32: UInt32 = 0       // offset 44, 4 bytes → ends at 48
        var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) =
            (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) // offset 48, 32 bytes
    } // TOTAL: 80 bytes ✓

    init() {
        assert(MemoryLayout<SMCParamStruct>.stride == Self.smcStructSizeExpected,
               "SMCParamStruct size mismatch: got \(MemoryLayout<SMCParamStruct>.stride), expected \(Self.smcStructSizeExpected)")
        _ = open()
    }

    deinit {
        close()
    }

    func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 { return false }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        return result == kIOReturnSuccess
    }

    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    /// Reads a single temp value for the first valid key in the list.
    func getTemperature(for keyLabels: [(key: String, label: String)]) -> Double {
        for entry in keyLabels {
            if let temp = readKey(entry.key), temp > 1.0 {
                return temp
            }
        }
        return 0.0
    }

    func getCPUTemperature() -> Double {
        let e = getTemperature(for: Self.efficiencyCoreKeys)
        let p = getTemperature(for: Self.performanceCoreKeys)
        let best = max(e, p)
        return best
    }

    func getGPUTemperature() -> Double {
        return getTemperature(for: Self.gpuKeys)
    }

    func getBatteryTemperature() -> Double {
        return getTemperature(for: Self.batteryKeys)
    }

    private func readKey(_ key: String) -> Double? {
        guard connection != 0 else { return nil }

        var inp = SMCParamStruct()
        var out = SMCParamStruct()

        inp.key = fourCharCode(key)
        inp.data8 = Self.SMC_CMD_READ_KEYINFO

        let sz = MemoryLayout<SMCParamStruct>.stride
        var outSz = sz

        // Step 1: get key metadata
        var kr = IOConnectCallStructMethod(connection, Self.KERNEL_INDEX_SMC, &inp, sz, &out, &outSz)
        if kr != kIOReturnSuccess || out.result != 0 { return nil }

        let dataType = out.keyInfo.dataType
        let dataSize = out.keyInfo.dataSize

        // Step 2: read key bytes
        inp = SMCParamStruct()
        out = SMCParamStruct()
        outSz = sz
        inp.key = fourCharCode(key)
        inp.keyInfo.dataSize = dataSize
        inp.data8 = Self.SMC_CMD_READ_BYTES

        kr = IOConnectCallStructMethod(connection, Self.KERNEL_INDEX_SMC, &inp, sz, &out, &outSz)
        if kr != kIOReturnSuccess || out.result != 0 { return nil }

        return convertToDouble(bytes: out.bytes, type: dataType, size: dataSize)
    }

    private func fourCharCode(_ s: String) -> UInt32 {
        var result: UInt32 = 0
        for char in s.utf8.prefix(4) {
            result = (result << 8) + UInt32(char)
        }
        return result
    }

    private func convertToDouble(bytes: Any, type: UInt32, size: UInt32) -> Double? {
        let typeStr = String(format: "%c%c%c%c",
                             UInt8((type >> 24) & 0xFF),
                             UInt8((type >> 16) & 0xFF),
                             UInt8((type >> 8) & 0xFF),
                             UInt8(type & 0xFF))

        return withUnsafeBytes(of: bytes) { raw in
            let ptr = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            if typeStr == "sp78" && size == 2 {
                let raw = Int16(ptr[0]) << 8 | Int16(ptr[1])
                let val = Double(raw) / 256.0
                return (val > 0 && val < 150) ? val : nil
            } else if typeStr == "flt " && size == 4 {
                var f: Float = 0
                memcpy(&f, ptr, 4)
                let val = Double(f)
                return (val > 0 && val < 150) ? val : nil
            } else if typeStr == "fpe2" && size == 2 {
                let raw = UInt16(ptr[0]) << 8 | UInt16(ptr[1])
                let val = Double(raw) / 4.0
                return (val > 0 && val < 150) ? val : nil
            }
            return nil
        }
    }
}
