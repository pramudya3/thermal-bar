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

    // Preferences
    @AppStorage("refreshInterval") var refreshInterval: Double = 0.5 // faster polling for real-time updates
    @AppStorage("highTempThreshold") var highTempThreshold: Double = 85.0

    
    // Menu Bar Settings
    @AppStorage("showFirstTemp") var showFirstTemp: Bool = true
    @AppStorage("firstTempType") var firstTempType: String = "Average CPU"
    @AppStorage("showSecondTemp") var showSecondTemp: Bool = true
    @AppStorage("secondTempType") var secondTempType: String = "Battery"
    @AppStorage("menuBarTextOrder") var menuBarTextOrder: String = "Vertical"

    // Services
    private let hidService = HIDThermalService()
    private let batteryService = BatteryService()
    private let smcService = SMCService()
    private let notificationService = NotificationService.shared
    private var timer: Timer?
    private var lastThermalState: ProcessInfo.ThermalState = .nominal

    init() {
        updateSensors()
        startPolling()
        setupWakeNotification()
    }

    private var sensorTimer: DispatchSourceTimer?

    func startPolling() {
        // Cancel any existing timer
        sensorTimer?.cancel()
        sensorTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        sensorTimer?.schedule(deadline: .now(), repeating: refreshInterval)
        sensorTimer?.setEventHandler { [weak self] in
            self?.updateSensors()
            self?.checkAlerts()
        }
        sensorTimer?.resume()
    }


    private func setupWakeNotification() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateSensors()
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
        self.cpuTemp = (smcPcore > 0) ? smcPcore : hid.cpuTemperature()
        
        self.batteryTemp = (smcBattery > 0) ? smcBattery : (gasGaugeReading?.temp ?? battInfo?.temperature ?? hid.batteryTemperature())
        // Create a single battery reading for the dashboard using the same real‑time temperature
        battList = [SensorReading(id: "Battery", label: "Battery", temperature: self.batteryTemp)]
        
        DispatchQueue.main.async {
            // Disable CPU deduplication to show all core package sensors
            self.cpuReadings = cpuList.sorted(by: { $0.id < $1.id })
            self.gpuReadings = Self.dedupeLabels(gpuList)
            self.batteryReadings = battList
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

    private func checkAlerts() {
        let all = cpuReadings + gpuReadings + batteryReadings
        for r in all where r.temperature >= highTempThreshold {
            notificationService.sendHighTempWarning(sensor: r.label, temperature: r.temperature)
        }
        let state = ProcessInfo.processInfo.thermalState
        if state != lastThermalState {
            if state == .serious || state == .critical { notificationService.sendThrottlingAlert() }
            lastThermalState = state
        }
    }
}
