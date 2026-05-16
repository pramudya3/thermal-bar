import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var viewModel: ThermalViewModel
    @Binding var isPresented: Bool
    @State private var launchAtLogin = false
    
    let intervals = [1.0, 2.0, 5.0, 10.0]
    let displayModes = ["CPU & Battery", "CPU, GPU & Battery", "CPU Only", "GPU Only", "Battery Only"]
    let tempTypes = ["Average CPU", "GPU", "Battery"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            // Menu Bar Content
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Bar Content")
                    .font(.headline)
                
                HStack {
                    Toggle("Temperature", isOn: $viewModel.showFirstTemp)
                    Spacer()
                    Picker("", selection: $viewModel.firstTempType) {
                        ForEach(tempTypes, id: \.self) { type in Text(type).tag(type) }
                    }
                    .labelsHidden()
                    .disabled(!viewModel.showFirstTemp)
                }
                
                HStack {
                    Toggle("Second temperature", isOn: $viewModel.showSecondTemp)
                    Spacer()
                    Picker("", selection: $viewModel.secondTempType) {
                        ForEach(tempTypes, id: \.self) { type in Text(type).tag(type) }
                    }
                    .labelsHidden()
                    .disabled(!viewModel.showSecondTemp)
                }
                
                HStack {
                    Toggle("Fan RPM", isOn: .constant(false))
                        .disabled(true)
                    Spacer()
                    Picker("", selection: .constant("Average RPM")) {
                        Text("Average RPM").tag("Average RPM")
                    }
                    .labelsHidden()
                    .disabled(true)
                }
            }
            
            // Menu Bar Text Order
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Bar Text Order")
                    .font(.headline)
                
                Picker("", selection: $viewModel.menuBarTextOrder) {
                    Text("Horizontal").tag("Horizontal")
                    Text("Vertical").tag("Vertical")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            
            // Refresh Interval & Other
            VStack(alignment: .leading, spacing: 8) {
                Text("Refresh Interval")
                    .font(.headline)
                
                Picker("", selection: $viewModel.refreshInterval) {
                    ForEach(intervals, id: \.self) { interval in
                        Text("\(Int(interval))s").tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: viewModel.refreshInterval) { _, _ in
                    viewModel.startPolling()
                }
            }
            
            Toggle("Start at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    toggleLaunchAtLogin(newValue)
                }
            
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
