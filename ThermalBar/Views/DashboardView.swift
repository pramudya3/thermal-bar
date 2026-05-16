import SwiftUI

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

                    if !allEmpty {
                        SectionHeaderView(icon: "thermometer", title: "Temperatures")
                        
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
            .background(.regularMaterial)
        }
    }
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
