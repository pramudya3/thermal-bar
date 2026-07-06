import Foundation
import IOKit

struct BatteryInfo {
    let cycleCount: Int
    let health: Int
    let wattage: Double
    let temperature: Double
}

class BatteryService {
    private var service: io_service_t = 0

    init() {
        service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    }

    deinit {
        if service != 0 {
            IOObjectRelease(service)
        }
    }

    func getBatteryInfo() -> BatteryInfo? {
        if service == 0 { return nil }
        
        var props: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
        
        guard result == kIOReturnSuccess else {
            props?.release()
            return nil
        }
        
        guard let dict = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        let cycleCount = dict["CycleCount"] as? Int ?? 0
        let maxCapacity = dict["MaxCapacity"] as? Int ?? 100
        let designCapacity = dict["DesignCapacity"] as? Int ?? maxCapacity
        let health = designCapacity > 0 ? (maxCapacity * 100 / designCapacity) : 0
        
        let voltage = dict["Voltage"] as? Double ?? 0.0
        let amperage = dict["Amperage"] as? Double ?? 0.0
        let wattage = (voltage * amperage) / 1_000_000.0
        
        let temperature = (dict["Temperature"] as? Double ?? 0.0) / 100.0
        
        return BatteryInfo(
            cycleCount: cycleCount,
            health: health,
            wattage: wattage,
            temperature: temperature
        )
    }
}
