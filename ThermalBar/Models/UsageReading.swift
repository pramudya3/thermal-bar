import Foundation
import SwiftUI

struct UsageReading: Identifiable {
    let id: String
    let label: String
    let usage: Double // 0.0 to 100.0

    var formatted: String { "\(Int(usage.rounded()))%" }

    var color: Color {
        switch usage {
        case ..<60: return .primary
        case 60..<85: return .orange
        default: return .red
        }
    }
}
