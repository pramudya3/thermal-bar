import SwiftUI
import AppKit

func createMenuBarImage(items: [String], isVertical: Bool) -> NSImage {
    let totalHeight: CGFloat = 22
    let spacing: CGFloat = 5
    let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    let icon = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    
    let iconWidth: CGFloat = icon?.size.width ?? 6
    let iconHeight: CGFloat = icon?.size.height ?? 18
    
    // Bold, Crisp Font (9pt is perfect for integer alignment)
    let fontSize: CGFloat
    if isVertical {
        fontSize = items.count >= 2 ? 9 : 15
    } else {
        fontSize = 12
    }
    
    // Using bold design for a premium, heavy feel
    let fontDescriptor = NSFont.systemFont(ofSize: fontSize, weight: .bold).fontDescriptor
        .addingAttributes([.featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                                               NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]]])
    let font = NSFont(descriptor: fontDescriptor, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black
    ]
    
    let textWidth: CGFloat
    if isVertical && items.count >= 2 {
        let str1 = NSAttributedString(string: items[0], attributes: attributes)
        let str2 = NSAttributedString(string: items[1], attributes: attributes)
        textWidth = ceil(max(str1.size().width, str2.size().width))
    } else {
        let text = items.joined(separator: " / ")
        textWidth = ceil(NSAttributedString(string: text, attributes: attributes).size().width)
    }
    
    let totalWidth = ceil(iconWidth + spacing + textWidth)
    
    let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current else { return false }
        
        // Use high-quality antialiasing for sharp text on Retina displays
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true
        
        // Draw icon - centered for stability
        let iconRect = NSRect(x: 0, y: (totalHeight - iconHeight) / 2, width: iconWidth, height: iconHeight)
        icon?.draw(in: iconRect)
        
        // Draw text
        if isVertical && items.count >= 2 {
            let str1 = NSAttributedString(string: items[0], attributes: attributes)
            let str2 = NSAttributedString(string: items[1], attributes: attributes)
            
            // Pro Layout: Tightened for a "Full Bar" look like TG Pro
            // str2: 1.0 to 10.0 | GAP: 2.0px | str1: 12.0 to 21.0
            str1.draw(at: NSPoint(x: iconWidth + spacing, y: 12.0))
            str2.draw(at: NSPoint(x: iconWidth + spacing, y: 0.0))
        } else {
            let text = items.count >= 2 ? items.joined(separator: " / ") : items[0]
            let str = NSAttributedString(string: text, attributes: attributes)
            let textY = (totalHeight - str.size().height) / 2
            str.draw(at: NSPoint(x: iconWidth + spacing, y: textY))
        }
        
        return true
    }
    
    // Crucial: This makes the image adapt to Light/Dark mode automatically
    image.isTemplate = true
    return image
}

@main
struct ThermalBarApp: App {
    @StateObject private var viewModel = ThermalViewModel()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(viewModel: viewModel)
        } label: {
            let getTemp: (String) -> String? = { type in
                switch type {
                case "Average CPU": return "\(Int(viewModel.cpuTemp.rounded()))°C"
                case "GPU": 
                    let g = viewModel.gpuReadings.first?.temperature ?? 0
                    return g > 0 ? "\(Int(g.rounded()))°C" : nil
                case "Battery": return "\(Int(viewModel.batteryTemp.rounded()))°C"
                default: return nil
                }
            }
            
            let items: [String] = {
                var list = [String]()
                if viewModel.showFirstTemp, let t = getTemp(viewModel.firstTempType) { list.append(t) }
                if viewModel.showSecondTemp, let t = getTemp(viewModel.secondTempType) { list.append(t) }
                if list.isEmpty { list.append("\(Int(viewModel.cpuTemp.rounded()))°C") }
                return list
            }()
            
            Image(nsImage: createMenuBarImage(items: items, isVertical: viewModel.menuBarTextOrder == "Vertical"))
                .id("\(viewModel.cpuTemp)\(viewModel.batteryTemp)\(viewModel.menuBarTextOrder)\(items.count)")
        }
        .menuBarExtraStyle(.window)
    }
}
