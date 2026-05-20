import Foundation
import SwiftUI

/// A single temperature reading row.
struct SensorReading: Identifiable {
    let id: String
    let label: String
    let temperature: Double

    var formatted: String { "\(Int(temperature.rounded()))°C" }

    var color: Color {
        switch temperature {
        case ..<60: return .primary
        case 60..<80: return .orange
        default:    return .red
        }
    }
}

class ThermalViewModel: ObservableObject {
    // Menu bar display
    @Published var cpuTemp: Double = 0
    @Published var batteryTemp: Double = 0

    // Section rows
    @Published var cpuReadings: [SensorReading] = []
    @Published var gpuReadings: [SensorReading] = []
    @Published var batteryReadings: [SensorReading] = []
    
    @Published var cpuUsage: UsageReading?
    @Published var gpuUsage: UsageReading?
    @Published var memoryUsage: UsageReading?

    // Preferences manually synced with UserDefaults to avoid AppStorage memory/offset compiler bugs
    @Published var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        }
    }
    @Published var highTempThreshold: Double {
        didSet {
            UserDefaults.standard.set(highTempThreshold, forKey: "highTempThreshold")
        }
    }

    // Menu Bar Settings
    @Published var showFirstTemp: Bool {
        didSet {
            UserDefaults.standard.set(showFirstTemp, forKey: "showFirstTemp")
        }
    }
    @Published var firstTempType: String {
        didSet {
            UserDefaults.standard.set(firstTempType, forKey: "firstTempType")
        }
    }
    @Published var showSecondTemp: Bool {
        didSet {
            UserDefaults.standard.set(showSecondTemp, forKey: "showSecondTemp")
        }
    }
    @Published var secondTempType: String {
        didSet {
            UserDefaults.standard.set(secondTempType, forKey: "secondTempType")
        }
    }
    @Published var menuBarTextOrder: String {
        didSet {
            UserDefaults.standard.set(menuBarTextOrder, forKey: "menuBarTextOrder")
        }
    }
    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon")
        }
    }
    @Published var showCpuMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showCpuMenuBar, forKey: "showCpuMenuBar")
        }
    }
    @Published var showRamMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showRamMenuBar, forKey: "showRamMenuBar")
        }
    }
    @Published var showGpuMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showGpuMenuBar, forKey: "showGpuMenuBar")
        }
    }
    @Published var systemUsageLayout: String {
        didSet {
            UserDefaults.standard.set(systemUsageLayout, forKey: "systemUsageLayout")
        }
    }
    @Published var temperatureLayout: String {
        didSet {
            UserDefaults.standard.set(temperatureLayout, forKey: "temperatureLayout")
        }
    }

    // Services
    private let hidService = HIDThermalService()
    private let batteryService = BatteryService()
    private let smcService = SMCService()
    private let usageService = UsageService()
    private let notificationService = NotificationService.shared
    private var timer: Timer?
    private var lastThermalState: ProcessInfo.ThermalState = .nominal

    init() {
        let ud = UserDefaults.standard
        self.refreshInterval = ud.object(forKey: "refreshInterval") == nil ? 0.5 : ud.double(forKey: "refreshInterval")
        self.highTempThreshold = ud.object(forKey: "highTempThreshold") == nil ? 85.0 : ud.double(forKey: "highTempThreshold")
        
        self.showFirstTemp = ud.object(forKey: "showFirstTemp") == nil ? true : ud.bool(forKey: "showFirstTemp")
        self.firstTempType = ud.string(forKey: "firstTempType") ?? "Average CPU"
        self.showSecondTemp = ud.object(forKey: "showSecondTemp") == nil ? true : ud.bool(forKey: "showSecondTemp")
        self.secondTempType = ud.string(forKey: "secondTempType") ?? "Battery"
        self.menuBarTextOrder = ud.string(forKey: "menuBarTextOrder") ?? "Vertical"
        self.showMenuBarIcon = true
        
        self.showCpuMenuBar = ud.bool(forKey: "showCpuMenuBar")
        self.showRamMenuBar = ud.bool(forKey: "showRamMenuBar")
        self.showGpuMenuBar = ud.bool(forKey: "showGpuMenuBar")
        
        self.systemUsageLayout = ud.string(forKey: "systemUsageLayout") ?? "Vertical"
        self.temperatureLayout = ud.string(forKey: "temperatureLayout") ?? "Vertical"
        
        updateSensors()
        startPolling()
        setupWakeNotification()
    }

    private let pollingQueue = DispatchQueue(label: "com.antigravity.ThermalBar.polling", qos: .userInitiated)
    private var sensorTimer: DispatchSourceTimer?

    func startPolling() {
        // Cancel any existing timer
        sensorTimer?.cancel()
        sensorTimer = DispatchSource.makeTimerSource(queue: pollingQueue)
        sensorTimer?.schedule(deadline: .now(), repeating: refreshInterval)
        sensorTimer?.setEventHandler { [weak self] in
            autoreleasepool {
                self?.updateSensors()
            }
        }
        sensorTimer?.resume()
    }


    private func setupWakeNotification() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.startPolling()
        }
    }

    private func updateSensors() {
        guard let hid = hidService else { return }

        let allReadings = hid.allReadings().sorted(by: { $0.name < $1.name })
        
        var cpuList: [SensorReading] = []
        var gpuList: [SensorReading] = []
        var battList: [SensorReading] = []


        for r in allReadings {
            let temp = r.temp
            if temp <= 0 || temp >= 150 { continue }
            
            let name = r.name
            if name.contains("pACC MTR") || name.contains("eACC MTR") || name.contains("p0 MTR") || name.contains("p1 MTR") || name.contains("e0 MTR") {
                let label = (name.contains("pACC") || name.contains("p0") || name.contains("p1")) ? "Performance Cores Package" : "Efficiency Cores Package"
                cpuList.append(SensorReading(id: name, label: label, temperature: temp))
            } else if name.contains("GPU MTR") {
                gpuList.append(SensorReading(id: name, label: "GPU", temperature: temp))
            }
        }
        
        let battInfo = batteryService.getBatteryInfo()
        let gasGaugeReading = allReadings.first(where: { $0.name.lowercased().contains("gas gauge") })
        
        // Prioritize SMC for more real-time battery gas gauge if available
        let smcBattery = smcService.getBatteryTemperature()
        
        // Prioritize Performance Core for the menu bar CPU reading
        let smcPcore = smcService.getCPUTemperature()
        let finalCpuTemp = (smcPcore > 0) ? smcPcore : hid.cpuTemperature()
        
        let finalBatteryTemp = (smcBattery > 0) ? smcBattery : (gasGaugeReading?.temp ?? battInfo?.temperature ?? hid.batteryTemperature())
        // Create a single battery reading for the dashboard using the same real‑time temperature
        battList = [SensorReading(id: "Battery", label: "Battery", temperature: finalBatteryTemp)]
        
        // Fetch Usage Metrics
        let cpuPct = usageService.getCPUUsage()
        let memoryPct = usageService.getMemoryUsage()
        let gpuPct = usageService.getGPUUsage()
        
        let cpuUsageReading = UsageReading(id: "CPUUsage", label: "CPU Usage", usage: cpuPct)
        let memoryUsageReading = UsageReading(id: "MemUsage", label: "Memory Usage", usage: memoryPct)
        let gpuUsageReading = UsageReading(id: "GPUUsage", label: "GPU Usage", usage: gpuPct)
        
        let sortedCpuList = cpuList.sorted(by: { $0.id < $1.id })
        let dedupedGpuList = Self.dedupeLabels(gpuList)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cpuTemp = finalCpuTemp
            self.batteryTemp = finalBatteryTemp
            // Disable CPU deduplication to show all core package sensors
            self.cpuReadings = sortedCpuList
            self.gpuReadings = dedupedGpuList
            self.batteryReadings = battList
            
            self.cpuUsage = cpuUsageReading
            self.memoryUsage = memoryUsageReading
            self.gpuUsage = gpuUsageReading
            
            self.checkAlerts()
        }
    }

    private static func dedupeLabels(_ readings: [SensorReading]) -> [SensorReading] {
        var seen = Set<String>()
        var result = [SensorReading]()
        for r in readings {
            if !seen.contains(r.label) {
                seen.insert(r.label)
                result.append(r)
            }
        }
        return result
    }

    /// Remove duplicate readings (within 0.5°C of each other).
    private static func dedupe(_ readings: [(name: String, temp: Double)]) -> [(name: String, temp: Double)] {
        var seen = [Double]()
        return readings.filter { r in
            guard !seen.contains(where: { abs($0 - r.temp) < 0.5 }) else { return false }
            seen.append(r.temp)
            return true
        }
    }

    private var lastAlertTimes: [String: Date] = [:]

    private func checkAlerts() {
        let all = cpuReadings + gpuReadings + batteryReadings
        let now = Date()
        
        for r in all where r.temperature >= highTempThreshold {
            let lastAlertTime = lastAlertTimes[r.label] ?? Date.distantPast
            if now.timeIntervalSince(lastAlertTime) >= 300 {
                notificationService.sendHighTempWarning(sensor: r.label, temperature: r.temperature)
                lastAlertTimes[r.label] = now
            }
        }
        let state = ProcessInfo.processInfo.thermalState
        if state != lastThermalState {
            if state == .serious || state == .critical { notificationService.sendThrottlingAlert() }
            lastThermalState = state
        }
    }
}
