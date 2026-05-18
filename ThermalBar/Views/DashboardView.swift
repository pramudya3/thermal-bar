import SwiftUI
import AppKit

struct DashboardView: View {
    @ObservedObject var viewModel: ThermalViewModel
    @State private var showingSettings = false

    var body: some View {
        if showingSettings {
            SettingsView(viewModel: viewModel, isPresented: $showingSettings)
                .background(.regularMaterial)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                HStack {
                    Image(systemName: "thermometer.large")
                        .foregroundColor(.secondary)
                    Text("Thermal Bar")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

                Divider()

                // ── Sensor Sections ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    
                    let allEmpty = viewModel.cpuReadings.isEmpty && viewModel.gpuReadings.isEmpty && viewModel.batteryReadings.isEmpty
                    let hasUsage = viewModel.cpuUsage != nil || viewModel.memoryUsage != nil || viewModel.gpuUsage != nil

                    if !allEmpty || hasUsage {
                        if hasUsage {
                            SectionHeaderView(icon: "chart.pie", title: "System Usage")
                            
                            if viewModel.systemUsageLayout == "Horizontal" {
                                HStack(spacing: 11) {
                                    if let cpu = viewModel.cpuUsage {
                                        CompactUsageView(reading: cpu)
                                    }
                                    if let mem = viewModel.memoryUsage {
                                        CompactUsageView(reading: mem)
                                    }
                                    if let gpu = viewModel.gpuUsage {
                                        CompactUsageView(reading: gpu)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            } else {
                                if let cpu = viewModel.cpuUsage {
                                    UsageRowView(reading: cpu)
                                }
                                if let mem = viewModel.memoryUsage {
                                    UsageRowView(reading: mem)
                                }
                                if let gpu = viewModel.gpuUsage {
                                    UsageRowView(reading: gpu)
                                }
                            }
                            
                            Spacer().frame(height: 10)
                        }

                        if !allEmpty {
                            SectionHeaderView(icon: "thermometer", title: "Temperatures")
                            
                            if viewModel.temperatureLayout == "Horizontal" {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !viewModel.cpuReadings.isEmpty {
                                        Text("CPU SENSORS")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 14)
                                        
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                            ForEach(viewModel.cpuReadings) { r in
                                                CompactSensorView(label: r.label, temperature: r.temperature, formattedTemp: r.formatted, color: r.color)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                    }
                                    
                                    if !viewModel.gpuReadings.isEmpty {
                                        Text("GPU SENSORS")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 14)
                                            .padding(.top, 4)
                                        
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                            ForEach(viewModel.gpuReadings) { r in
                                                CompactSensorView(label: r.label, temperature: r.temperature, formattedTemp: r.formatted, color: r.color)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                    }
                                    
                                    if !viewModel.batteryReadings.isEmpty {
                                        Text("BATTERY SENSORS")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 14)
                                            .padding(.top, 4)
                                        
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                            ForEach(viewModel.batteryReadings) { r in
                                                CompactSensorView(label: r.label, temperature: r.temperature, formattedTemp: r.formatted, color: r.color)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                    }
                                }
                                Spacer().frame(height: 10)
                            } else {
                                if !viewModel.cpuReadings.isEmpty {
                                    ForEach(viewModel.cpuReadings) { r in 
                                        SensorRowView(label: r.label, temperature: r.temperature, formattedTemp: r.formatted, color: r.color) 
                                    }
                                    Spacer().frame(height: 10)
                                }
                                
                                if !viewModel.gpuReadings.isEmpty {
                                    ForEach(viewModel.gpuReadings) { r in 
                                        SensorRowView(label: r.label, temperature: r.temperature, formattedTemp: r.formatted, color: r.color) 
                                    }
                                    Spacer().frame(height: 10)
                                }
                                
                                if !viewModel.batteryReadings.isEmpty {
                                    ForEach(viewModel.batteryReadings) { r in 
                                        SensorRowView(label: r.label, temperature: r.temperature, formattedTemp: r.formatted, color: r.color) 
                                    }
                                    Spacer().frame(height: 10)
                                }
                            }
                        } // Close if !allEmpty
                    } else {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.secondary)
                                Text("No sensor data available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    }
                }
                .padding(.bottom, 10)

                // ── Footer ───────────────────────────────────────────────
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(width: 350)
            .background(
                WindowAccessor { window in
                    let currentId = window.windowNumber
                    for w in NSApplication.shared.windows {
                        if w.windowNumber != currentId {
                            let className = String(describing: type(of: w))
                            if w.title.isEmpty || className.contains("Status") || className.contains("Panel") {
                                w.orderOut(nil)
                            }
                        }
                    }
                }
            )
            .background(.regularMaterial)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onAccess: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onAccess(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// ── Section Header ────────────────────────────────────────────────────────────
struct SectionHeaderView: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 12, weight: .medium))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// ── Sensor Row ────────────────────────────────────────────────────────────────
struct SensorRowView: View {
    let label: String
    let temperature: Double
    let formattedTemp: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formattedTemp)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }
}

// ── Usage Row ─────────────────────────────────────────────────────────────────
struct UsageRowView: View {
    let reading: UsageReading

    var body: some View {
        HStack(spacing: 12) {
            Text(reading.label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(width: 110, alignment: .leading)
            
            ProgressView(value: min(max(reading.usage, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(reading.color)
            
            Text(reading.formatted)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(reading.color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }
}

// ── Compact Usage Block ────────────────────────────────────────────────────────
struct CompactUsageView: View {
    let reading: UsageReading

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
                Text(reading.label.replacingOccurrences(of: " Usage", with: ""))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(reading.formatted)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(reading.color)
            }
            ProgressView(value: min(max(reading.usage, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(reading.color)
                .scaleEffect(x: 1, y: 0.8, anchor: .center)
        }
        .frame(width: 100)
    }
}

// ── Compact Sensor Block ───────────────────────────────────────────────────────
struct CompactSensorView: View {
    let label: String
    let temperature: Double
    let formattedTemp: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(formattedTemp)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
    }
}
