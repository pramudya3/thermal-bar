import SwiftUI
import AppKit

func createMenuBarImage(items: [String], isVertical: Bool, iconName: String = "thermometer.medium", showIcon: Bool = true) -> NSImage {
    let totalHeight: CGFloat = 22
    let spacing: CGFloat = 5
    
    let iconWidth: CGFloat
    let iconHeight: CGFloat
    let icon: NSImage?
    
    if showIcon {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        iconWidth = icon?.size.width ?? 6
        iconHeight = icon?.size.height ?? 18
    } else {
        icon = nil
        iconWidth = 0
        iconHeight = 0
    }
    
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
    
    let actualSpacing = showIcon ? spacing : 0
    let totalWidth = ceil(iconWidth + actualSpacing + textWidth)
    
    let scale: CGFloat = 2.0
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(totalWidth * scale),
        pixelsHigh: Int(totalHeight * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: totalWidth, height: totalHeight)
    
    let context = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    
    if let ctx = context {
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true
    }
    
    // Draw icon - centered for stability
    if showIcon {
        let iconRect = NSRect(x: 0, y: (totalHeight - iconHeight) / 2, width: iconWidth, height: iconHeight)
        icon?.draw(in: iconRect)
    }
    
    let textX = iconWidth + actualSpacing
    
    // Draw text
    if isVertical && items.count >= 2 {
        let str1 = NSAttributedString(string: items[0], attributes: attributes)
        let str2 = NSAttributedString(string: items[1], attributes: attributes)
        
        // Pro Layout: Tightened for a "Full Bar" look like TG Pro
        str1.draw(at: NSPoint(x: textX, y: 12.0))
        str2.draw(at: NSPoint(x: textX, y: 0.0))
    } else {
        let text = items.count >= 2 ? items.joined(separator: " / ") : items[0]
        let str = NSAttributedString(string: text, attributes: attributes)
        let textY = (totalHeight - str.size().height) / 2
        str.draw(at: NSPoint(x: textX, y: textY))
    }
    
    NSGraphicsContext.restoreGraphicsState()
    
    let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
    image.addRepresentation(rep)
    
    // Crucial: This makes the image adapt to Light/Dark mode automatically
    image.isTemplate = true
    return image
}

func createLinearProgressMenuBarImage(label: String, value: Double) -> NSImage {
    let totalHeight: CGFloat = 22
    let barWidth: CGFloat = 30
    let barHeight: CGFloat = 5
    let barY = (totalHeight - barHeight) / 2.0 - 1.0
    let spacing: CGFloat = 6
    
    // Font: 12pt bold (matches the temperature display size perfectly)
    let fontSize: CGFloat = 12
    let fontDescriptor = NSFont.systemFont(ofSize: fontSize, weight: .semibold).fontDescriptor
        .addingAttributes([.featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                                               NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]]])
    let font = NSFont(descriptor: fontDescriptor, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    
    // Size computations (independent of light/dark color)
    let sizeAttributes: [NSAttributedString.Key: Any] = [.font: font]
    let labelStrSize = NSAttributedString(string: label, attributes: sizeAttributes).size()
    let labelWidth = ceil(labelStrSize.width)
    
    let percentText = "\(Int(value.rounded()))%"
    let valueStrSize = NSAttributedString(string: percentText, attributes: sizeAttributes).size()
    let valueWidth = ceil(valueStrSize.width)
    
    // We add 1.0 point padding at start and end to avoid clipping
    let totalWidth = 2.0 + labelWidth + spacing + barWidth + spacing + valueWidth
    
    let scale: CGFloat = 2.0
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(totalWidth * scale),
        pixelsHigh: Int(totalHeight * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: totalWidth, height: totalHeight)
    
    let context = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    
    if let ctx = context {
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true
    }
    
    // 0. Detect Light / Dark Mode dynamically
    var isDarkMode = false
    if let best = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) {
        isDarkMode = (best == .darkAqua)
    }
    
    let textColor = isDarkMode ? NSColor.white : NSColor.black
    let trackColor = isDarkMode ? NSColor.white.withAlphaComponent(0.2) : NSColor.black.withAlphaComponent(0.2)
    
    let fillColor: NSColor
    if value < 60.0 {
        fillColor = textColor
    } else if value < 85.0 {
        fillColor = NSColor.systemOrange
    } else {
        fillColor = NSColor.systemRed
    }
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor
    ]
    
    let labelStr = NSAttributedString(string: label, attributes: attributes)
    let valueStr = NSAttributedString(string: percentText, attributes: attributes)
    
    // 1. Draw Label Text on the left
    let labelY = (totalHeight - labelStr.size().height) / 2.0
    labelStr.draw(at: NSPoint(x: 1.0, y: labelY))
    
    // 2. Draw Progress Bar Background Track
    let barX = 1.0 + labelWidth + spacing
    let bgPath = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barWidth, height: barHeight), xRadius: 2.5, yRadius: 2.5)
    trackColor.set()
    bgPath.fill()
    
    // 3. Draw Progress Bar Fill
    if value > 0.0 {
        let fillPercent = min(max(CGFloat(value) / 100.0, 0.0), 1.0)
        let fillWidth = max(fillPercent * barWidth, 2.0) // Keep at least 2px width if positive for visibility
        let fillPath = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: fillWidth, height: barHeight), xRadius: 2.5, yRadius: 2.5)
        fillColor.set()
        fillPath.fill()
    }
    
    // 4. Draw Value Text on the right
    let valueX = barX + barWidth + spacing
    let valueY = (totalHeight - valueStr.size().height) / 2.0
    valueStr.draw(at: NSPoint(x: valueX, y: valueY))
    
    NSGraphicsContext.restoreGraphicsState()
    
    let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
    image.addRepresentation(rep)
    image.isTemplate = false
    return image
}

func createCombinedVerticalUsageMenuBarImage(cpu: Double?, ram: Double?, gpu: Double?) -> NSImage {
    let totalHeight: CGFloat = 22
    
    // Determine active metrics
    var activeMetrics: [(label: String, val: Double)] = []
    if let c = cpu { activeMetrics.append(("CPU", c)) }
    if let r = ram { activeMetrics.append(("RAM", r)) }
    if let g = gpu { activeMetrics.append(("GPU", g)) }
    
    if activeMetrics.isEmpty {
        return NSImage()
    }
    
    let count = activeMetrics.count
    let fontSize: CGFloat
    let barHeight: CGFloat
    let barWidth: CGFloat
    switch count {
    case 1:
        fontSize = 12.0
        barHeight = 5.0
        barWidth = 30.0
    case 2:
        fontSize = 8.0
        barHeight = 2.5
        barWidth = 16.0
    default:
        fontSize = 6.5
        barHeight = 1.8
        barWidth = 16.0
    }
    
    let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
    let tempAttributes: [NSAttributedString.Key: Any] = [.font: font]
    
    var maxLabelWidth: CGFloat = 0
    var maxPctWidth: CGFloat = 0
    
    for metric in activeMetrics {
        let labelSize = NSAttributedString(string: metric.label, attributes: tempAttributes).size().width
        let pctSize = NSAttributedString(string: "\(Int(metric.val.rounded()))%", attributes: tempAttributes).size().width
        maxLabelWidth = max(maxLabelWidth, labelSize)
        maxPctWidth = max(maxPctWidth, pctSize)
    }
    
    maxLabelWidth = ceil(maxLabelWidth)
    maxPctWidth = ceil(maxPctWidth)
    
    let totalWidth = 2.0 + maxLabelWidth + 3.0 + barWidth + 3.0 + maxPctWidth + 2.0
    
    let scale: CGFloat = 2.0
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(totalWidth * scale),
        pixelsHigh: Int(totalHeight * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: totalWidth, height: totalHeight)
    
    let context = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    
    if let ctx = context {
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true
    }
    
    // Detect theme
    var isDarkMode = false
    if let best = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) {
        isDarkMode = (best == .darkAqua)
    }
    
    let textColor = isDarkMode ? NSColor.white : NSColor.black
    let trackColor = isDarkMode ? NSColor.white.withAlphaComponent(0.2) : NSColor.black.withAlphaComponent(0.2)
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor
    ]
    
    let rowHeight: CGFloat = totalHeight / CGFloat(count)
    
    for (index, metric) in activeMetrics.enumerated() {
        // Compute Y position (vertical layout)
        let yOffset = totalHeight - CGFloat(index + 1) * rowHeight + (rowHeight - fontSize) / 2.0 - 0.5
        let barOffset: CGFloat
        switch count {
        case 1: barOffset = -1.0
        case 2: barOffset = -0.5
        default: barOffset = -0.3
        }
        let barY = totalHeight - CGFloat(index + 1) * rowHeight + (rowHeight - barHeight) / 2.0 + barOffset
        
        // 1. Draw Label text on the left
        let labelStr = NSAttributedString(string: metric.label, attributes: attributes)
        labelStr.draw(at: NSPoint(x: 2.0, y: yOffset))
        
        // 2. Draw Progress Bar
        let barX = 2.0 + maxLabelWidth + 3.0
        let radius: CGFloat = count == 1 ? 2.5 : 1.0
        let bgPath = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barWidth, height: barHeight), xRadius: radius, yRadius: radius)
        trackColor.set()
        bgPath.fill()
        
        if metric.val > 0.0 {
            let fillPercent = min(max(CGFloat(metric.val) / 100.0, 0.0), 1.0)
            let fillWidth = max(fillPercent * barWidth, 1.0)
            let fillPath = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: fillWidth, height: barHeight), xRadius: radius, yRadius: radius)
            
            let fillColor: NSColor
            if metric.val < 60.0 {
                fillColor = textColor
            } else if metric.val < 85.0 {
                fillColor = NSColor.systemOrange
            } else {
                fillColor = NSColor.systemRed
            }
            
            fillColor.set()
            fillPath.fill()
        }
        
        // 3. Draw Percentage text on the right
        let pctText = "\(Int(metric.val.rounded()))%"
        let pctStr = NSAttributedString(string: pctText, attributes: attributes)
        let pctX = barX + barWidth + 3.0
        pctStr.draw(at: NSPoint(x: pctX, y: yOffset))
    }
    
    NSGraphicsContext.restoreGraphicsState()
    
    let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
    image.addRepresentation(rep)
    image.isTemplate = false
    return image
}

private final class MenuBarImageCache {
    static let shared = MenuBarImageCache()
    
    private var tempImageCache: [String: NSImage] = [:]
    private var combinedUsageImageCache: [String: NSImage] = [:]
    private var linearUsageImageCache: [String: NSImage] = [:]
    
    private var isDarkMode: Bool {
        if let best = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) {
            return best == .darkAqua
        }
        return false
    }
    
    func getTempImage(items: [String], isVertical: Bool, showIcon: Bool) -> NSImage {
        let key = "\(items.joined(separator: "-"))-\(isVertical)-\(showIcon)-\(isDarkMode)"
        if let cached = tempImageCache[key] {
            return cached
        }
        let newImg = createMenuBarImage(items: items, isVertical: isVertical, showIcon: showIcon)
        if tempImageCache.count > 50 { tempImageCache.removeAll() }
        tempImageCache[key] = newImg
        return newImg
    }
    
    func getCombinedUsageImage(cpu: Double?, ram: Double?, gpu: Double?) -> NSImage {
        let cpuInt = cpu != nil ? Int(cpu!.rounded()) : -1
        let ramInt = ram != nil ? Int(ram!.rounded()) : -1
        let gpuInt = gpu != nil ? Int(gpu!.rounded()) : -1
        let key = "\(cpuInt)-\(ramInt)-\(gpuInt)-\(isDarkMode)"
        if let cached = combinedUsageImageCache[key] {
            return cached
        }
        let newImg = createCombinedVerticalUsageMenuBarImage(cpu: cpu, ram: ram, gpu: gpu)
        if combinedUsageImageCache.count > 50 { combinedUsageImageCache.removeAll() }
        combinedUsageImageCache[key] = newImg
        return newImg
    }
    
    func getLinearUsageImage(label: String, value: Double) -> NSImage {
        let valInt = Int(value.rounded())
        let key = "\(label)-\(valInt)-\(isDarkMode)"
        if let cached = linearUsageImageCache[key] {
            return cached
        }
        let newImg = createLinearProgressMenuBarImage(label: label, value: value)
        if linearUsageImageCache.count > 50 { linearUsageImageCache.removeAll() }
        linearUsageImageCache[key] = newImg
        return newImg
    }
}

@main
struct ThermalBarApp: App {
    @StateObject private var viewModel = ThermalViewModel()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(viewModel: viewModel)
        } label: {
            let getMetric: (String) -> String? = { type in
                switch type {
                case "Average CPU": return "\(Int(viewModel.cpuTemp.rounded()))°C"
                case "GPU": 
                    let g = viewModel.gpuReadings.first?.temperature ?? 0
                    return g > 0 ? "\(Int(g.rounded()))°C" : nil
                case "Battery": return "\(Int(viewModel.batteryTemp.rounded()))°C"
                case "CPU Usage":
                    return viewModel.cpuUsage?.formatted
                case "GPU Usage":
                    return viewModel.gpuUsage?.formatted
                case "RAM Usage":
                    return viewModel.memoryUsage?.formatted
                default: return nil
                }
            }
            
            let items: [String] = {
                var list = [String]()
                if viewModel.showFirstTemp, let t = getMetric(viewModel.firstTempType) { list.append(t) }
                if viewModel.showSecondTemp, let t = getMetric(viewModel.secondTempType) { list.append(t) }
                if list.isEmpty { list.append("\(Int(viewModel.cpuTemp.rounded()))°C") }
                return list
            }()
            
            Image(nsImage: MenuBarImageCache.shared.getTempImage(items: items, isVertical: viewModel.menuBarTextOrder == "Vertical", showIcon: viewModel.showMenuBarIcon))
                .id("\(items.joined(separator: "-"))-\(viewModel.menuBarTextOrder)-\(viewModel.showMenuBarIcon)")
        }
        .menuBarExtraStyle(.window)
        
        // ── Single Unified Combined Status Item (Vertical Stacking) ──
        MenuBarExtra(isInserted: Binding(
            get: { (viewModel.showCpuMenuBar || viewModel.showRamMenuBar || viewModel.showGpuMenuBar) && viewModel.systemUsageLayout == "Vertical" },
            set: { _ in }
        )) {
            DashboardView(viewModel: viewModel)
        } label: {
            let cpuVal = viewModel.showCpuMenuBar ? (viewModel.cpuUsage?.usage ?? 0.0) : nil
            let ramVal = viewModel.showRamMenuBar ? (viewModel.memoryUsage?.usage ?? 0.0) : nil
            let gpuVal = viewModel.showGpuMenuBar ? (viewModel.gpuUsage?.usage ?? 0.0) : nil
            
            let cacheId = "combined-vertical-\(Int(cpuVal ?? -1))-\(Int(ramVal ?? -1))-\(Int(gpuVal ?? -1))"
            Image(nsImage: MenuBarImageCache.shared.getCombinedUsageImage(cpu: cpuVal, ram: ramVal, gpu: gpuVal))
                .id(cacheId)
        }
        .menuBarExtraStyle(.window)
        
        // ── Individual Separated Status Items (Horizontal Layout) ──
        MenuBarExtra(isInserted: Binding(
            get: { viewModel.showCpuMenuBar && viewModel.systemUsageLayout == "Horizontal" },
            set: { _ in }
        )) {
            DashboardView(viewModel: viewModel)
        } label: {
            let val = viewModel.cpuUsage?.usage ?? 0.0
            Image(nsImage: MenuBarImageCache.shared.getLinearUsageImage(label: "CPU", value: val))
                .id("cpu-menubar-\(Int(val.rounded()))")
        }
        .menuBarExtraStyle(.window)
        
        MenuBarExtra(isInserted: Binding(
            get: { viewModel.showRamMenuBar && viewModel.systemUsageLayout == "Horizontal" },
            set: { _ in }
        )) {
            DashboardView(viewModel: viewModel)
        } label: {
            let val = viewModel.memoryUsage?.usage ?? 0.0
            Image(nsImage: MenuBarImageCache.shared.getLinearUsageImage(label: "RAM", value: val))
                .id("ram-menubar-\(Int(val.rounded()))")
        }
        .menuBarExtraStyle(.window)
        
        MenuBarExtra(isInserted: Binding(
            get: { viewModel.showGpuMenuBar && viewModel.systemUsageLayout == "Horizontal" },
            set: { _ in }
        )) {
            DashboardView(viewModel: viewModel)
        } label: {
            let val = viewModel.gpuUsage?.usage ?? 0.0
            Image(nsImage: MenuBarImageCache.shared.getLinearUsageImage(label: "GPU", value: val))
                .id("gpu-menubar-\(Int(val.rounded()))")
        }
        .menuBarExtraStyle(.window)
    }
}
