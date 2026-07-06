import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private var hasRequestedAuth = false
    
    private func ensureAuthorized() {
        guard !hasRequestedAuth else { return }
        hasRequestedAuth = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    func sendHighTempWarning(sensor: String, temperature: Double) {
        ensureAuthorized()
        let content = UNMutableNotificationContent()
        content.title = "High Temperature Warning"
        content.body = "\(sensor) has reached \(String(format: "%.1f", temperature))°C."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "high_temp_\(sensor)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendThrottlingAlert() {
        ensureAuthorized()
        let content = UNMutableNotificationContent()
        content.title = "System Throttling"
        content.body = "Thermal throttling has been detected. System performance may be reduced."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "thermal_throttling",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
