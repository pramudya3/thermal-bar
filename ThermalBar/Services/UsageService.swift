import Foundation
import Darwin
import IOKit

class UsageService {
    // For CPU Usage
    private var previousInfo: processor_info_array_t?
    private var previousInfoCount: mach_msg_type_number_t = 0
    
    func getCPUUsage() -> Double {
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var numProcessors: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numProcessors, &info, &infoCount)
        guard result == KERN_SUCCESS, let cpuInfo = info else { return 0 }
        
        var totalUsage: Double = 0
        
        if let prevInfo = previousInfo {
            var totalUser: UInt32 = 0
            var totalSystem: UInt32 = 0
            var totalIdle: UInt32 = 0
            var totalNice: UInt32 = 0
            
            for i in 0..<Int(numProcessors) {
                let baseIndex = Int(CPU_STATE_MAX) * i
                let user = UInt32(cpuInfo[baseIndex + Int(CPU_STATE_USER)]) - UInt32(prevInfo[baseIndex + Int(CPU_STATE_USER)])
                let system = UInt32(cpuInfo[baseIndex + Int(CPU_STATE_SYSTEM)]) - UInt32(prevInfo[baseIndex + Int(CPU_STATE_SYSTEM)])
                let idle = UInt32(cpuInfo[baseIndex + Int(CPU_STATE_IDLE)]) - UInt32(prevInfo[baseIndex + Int(CPU_STATE_IDLE)])
                let nice = UInt32(cpuInfo[baseIndex + Int(CPU_STATE_NICE)]) - UInt32(prevInfo[baseIndex + Int(CPU_STATE_NICE)])
                
                totalUser += user
                totalSystem += system
                totalIdle += idle
                totalNice += nice
            }
            
            let total = totalUser + totalSystem + totalIdle + totalNice
            if total > 0 {
                let used = totalUser + totalSystem + totalNice
                totalUsage = Double(used) / Double(total) * 100.0
            }
        }
        
        if let prevInfo = previousInfo {
            let prevInfoSize = vm_size_t(previousInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), prevInfoSize)
        }
        
        previousInfo = info
        previousInfoCount = infoCount
        
        return totalUsage
    }
    
    func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let pageSize = UInt64(vm_kernel_page_size)
        
        // Core system page components converted to absolute bytes
        let wiredBytes      = UInt64(stats.wire_count) * pageSize
        let activeBytes     = UInt64(stats.active_count) * pageSize
        let compressedBytes = UInt64(stats.compressor_page_count) * pageSize
        let inactiveBytes   = UInt64(stats.inactive_count) * pageSize
        let freeBytes       = UInt64(stats.free_count) * pageSize
        
        // Core working set (Unpurgeable assets)
        let internalUsed = wiredBytes + activeBytes + compressedBytes
        
        // Total physical allocation context minus purgeable file buffers
        let totalStructuralCommit = internalUsed + inactiveBytes
        
        let totalCapacity = totalStructuralCommit + freeBytes
        
        if totalCapacity > 0 {
            let pressurePercentage = (Double(internalUsed) / Double(totalCapacity)) * 100.0
            return min(max(pressurePercentage, 0.0), 100.0) // Clamp between 0 and 100
        }
        
        return 0.0
    }
    
    func getGPUUsage() -> Double {
        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) != kIOReturnSuccess {
            return 0
        }
        
        var maxUsage: Double = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let perfStats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                if let utilization = perfStats["Device Utilization %"] as? NSNumber {
                    maxUsage = max(maxUsage, utilization.doubleValue)
                } else if let utilization = perfStats["GPU Core Utilization"] as? NSNumber {
                    maxUsage = max(maxUsage, utilization.doubleValue)
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return maxUsage
    }
}
