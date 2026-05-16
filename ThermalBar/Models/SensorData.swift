import SwiftUI

enum SensorType: String {
    case cpu = "CPU"
    case gpu = "GPU"
    case battery = "Battery"
}

struct SensorData: Identifiable {
    let id = UUID()
    let type: SensorType
    let temperature: Double
    let label: String
    let secondaryInfo: String?
    let history: [Double]
    
    var formattedTemperature: String {
        return String(format: "%.1f°C", temperature)
    }
    
    var statusColor: Color {
        if temperature < 60 {
            return .green
        } else if temperature < 85 {
            return .orange
        } else {
            return .red
        }
    }
}
