import SwiftUI
import TerracottaShared

struct SettingsView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    
    @State private var logLevel = LogLevel.info
    @State private var useICloud = false
    @State private var preserveLogs = 1000
    @State private var statusRefreshInterval = 1.0
    @State private var useRealDeviceName = true
    @State private var plainTextIPInput = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Form {
                Section(header: Text("General")) {
                    Toggle("Use iCloud for Profiles", isOn: $useICloud)
                    Toggle("Use Real Device Name as Default", isOn: $useRealDeviceName)
                    Toggle("Plain Text IP Input", isOn: $plainTextIPInput)
                }
                
                Section(header: Text("Logging")) {
                    Picker("Log Level", selection: $logLevel) {
                        ForEach(LogLevel.allCases, id: \.self) {
                            level in
                            Text(level.rawValue)
                        }
                    }
                    
                    Stepper("Preserved Log Lines: \(preserveLogs)", value: $preserveLogs, in: 100...10000, step: 100)
                }
                
                Section(header: Text("Performance")) {
                    Stepper("Status Refresh Interval: \(statusRefreshInterval, specifier: "%.1f")s", value: $statusRefreshInterval, in: 0.1...5.0, step: 0.1)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                    }
                    
                    HStack {
                        Text("EasyTier Version")
                        Spacer()
                        Text("2.5.0")
                    }
                }
            }

            
            Spacer()
        }
        .padding()
        .onAppear {
            loadSettings()
        }
        .onDisappear {
            saveSettings()
        }
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        logLevel = LogLevel(rawValue: defaults.string(forKey: "logLevel") ?? LogLevel.info.rawValue) ?? .info
        useICloud = defaults.bool(forKey: "profilesUseICloud")
        preserveLogs = defaults.integer(forKey: "logPreservedLines")
        statusRefreshInterval = defaults.double(forKey: "statusRefreshInterval")
        useRealDeviceName = defaults.bool(forKey: "useRealDeviceNameAsDefault")
        plainTextIPInput = defaults.bool(forKey: "plainTextIPInput")
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(logLevel.rawValue, forKey: "logLevel")
        defaults.set(useICloud, forKey: "profilesUseICloud")
        defaults.set(preserveLogs, forKey: "logPreservedLines")
        defaults.set(statusRefreshInterval, forKey: "statusRefreshInterval")
        defaults.set(useRealDeviceName, forKey: "useRealDeviceNameAsDefault")
        defaults.set(plainTextIPInput, forKey: "plainTextIPInput")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ProfileStore())
    }
}
