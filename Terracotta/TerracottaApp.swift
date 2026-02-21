import SwiftUI
import os

@main
struct TerracottaApp: App {
    @StateObject private var networkManager = NetworkExtensionManager()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var logTailer = LogTailer()
    
    init() {
        let values: [String: Any] = [
            "logLevel": LogLevel.info.rawValue,
            "statusRefreshInterval": 1.0,
            "logPreservedLines": 1000,
            "useRealDeviceNameAsDefault": true,
            "plainTextIPInput": false,
            "profilesUseICloud": false,
        ]
        let sharedValues: [String: Any] = [
            "includeAllNetworks": false,
            "excludeLocalNetworks": true,
            "excludeCellularServices": true,
            "excludeAPNs": true,
            "excludeDeviceCommunication": true,
            "enforceRoutes": false,
        ]
        UserDefaults.standard.register(defaults: values)
        UserDefaults(suiteName: APP_GROUP_ID)?.register(defaults: sharedValues)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkManager)
                .environmentObject(profileStore)
                .environmentObject(logTailer)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("About Terracotta") {
                    // 显示关于窗口
                }
            }
            CommandGroup(replacing: .appInfo) {
                Button("Settings") {
                    // 显示设置窗口
                }
            }
        }
    }
}
