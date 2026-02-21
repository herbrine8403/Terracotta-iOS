import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var networkManager: NetworkExtensionManager
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var logTailer: LogTailer
    
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab {
        case dashboard
        case rooms
        case settings
        case logs
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
                .tag(Tab.dashboard)
            
            RoomsView()
                .tabItem {
                    Label("Rooms", systemImage: "person.3")
                }
                .tag(Tab.rooms)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
            
            LogView()
                .tabItem {
                    Label("Logs", systemImage: "scroll.text")
                }
                .tag(Tab.logs)
        }
        .onAppear {
            logTailer.start()
        }
        .onDisappear {
            logTailer.stop()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NetworkExtensionManager())
            .environmentObject(ProfileStore())
            .environmentObject(LogTailer())
    }
}
