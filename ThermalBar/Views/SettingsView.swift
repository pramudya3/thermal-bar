import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var viewModel: ThermalViewModel
    @Binding var isPresented: Bool
    @State private var launchAtLogin = false
    
    let intervals = [0.5, 1.0, 2.0, 5.0, 10.0]
    let metricTypes = ["Average CPU", "GPU", "Battery", "CPU Usage", "GPU Usage", "RAM Usage"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            // ── TEMPERATURE SECTION ──
            VStack(alignment: .leading, spacing: 10) {
                Text("Temperature Section")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("Primary Metric", isOn: $viewModel.showFirstTemp)
                        Spacer()
                        Picker("", selection: $viewModel.firstTempType) {
                            ForEach(metricTypes, id: \.self) { type in Text(type).tag(type) }
                        }
                        .labelsHidden()
                        .disabled(!viewModel.showFirstTemp)
                    }
                    
                    HStack {
                        Toggle("Secondary Metric", isOn: $viewModel.showSecondTemp)
                        Spacer()
                        Picker("", selection: $viewModel.secondTempType) {
                            ForEach(metricTypes, id: \.self) { type in Text(type).tag(type) }
                        }
                        .labelsHidden()
                        .disabled(!viewModel.showSecondTemp)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menu Bar Text Order")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $viewModel.menuBarTextOrder) {
                                Text("Horizontal").tag("Horizontal")
                                Text("Vertical").tag("Vertical")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dashboard Layout")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $viewModel.temperatureLayout) {
                                Text("Horizontal").tag("Horizontal")
                                Text("Vertical").tag("Vertical")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }

                    Toggle("Show Menu Bar Icon", isOn: $viewModel.showMenuBarIcon)
                }
                .padding(.leading, 8)
            }
            
            Divider()
            
            // ── SYSTEM USAGE SECTION ──
            VStack(alignment: .leading, spacing: 10) {
                Text("System Usage Section")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show CPU Usage in Menu Bar", isOn: $viewModel.showCpuMenuBar)
                    Toggle("Show RAM Usage in Menu Bar", isOn: $viewModel.showRamMenuBar)
                    Toggle("Show GPU Usage in Menu Bar", isOn: $viewModel.showGpuMenuBar)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage Layout (Menu Bar & Dashboard)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.systemUsageLayout) {
                            Text("Horizontal").tag("Horizontal")
                            Text("Vertical").tag("Vertical")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.leading, 8)
            }
            
            Divider()
            
            // ── REFRESH & GENERAL ──
            VStack(alignment: .leading, spacing: 10) {
                Text("Refresh Interval")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $viewModel.refreshInterval) {
                    ForEach(intervals, id: \.self) { interval in
                        Text(interval == 0.5 ? "0.5s" : "\(Int(interval))s").tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: viewModel.refreshInterval) { _, _ in
                    viewModel.startPolling()
                }
                .padding(.leading, 8)
            }
            
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Temperature Alert Threshold")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable Temperature Alerts", isOn: $viewModel.notificationsEnabled)

                    HStack {
                        Text("Notify when any sensor exceeds")
                            .font(.system(size: 12))
                        Text("\(Int(viewModel.highTempThreshold))°C")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(viewModel.highTempThreshold >= 80 ? .red : .orange)
                    }
                    .disabled(!viewModel.notificationsEnabled)

                    Slider(value: $viewModel.highTempThreshold, in: 60...100, step: 5)
                        .padding(.trailing, 8)
                        .disabled(!viewModel.notificationsEnabled)
                }
                .padding(.leading, 8)
            }

            Toggle("Start at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    toggleLaunchAtLogin(newValue)
                }
                .padding(.leading, 8)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }
    
    private func checkLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login status: \(error)")
        }
    }
}
