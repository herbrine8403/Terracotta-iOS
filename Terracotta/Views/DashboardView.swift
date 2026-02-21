import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var networkManager: NetworkExtensionManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Terracotta")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ConnectionStatusCard()
            
            HStack(spacing: 20) {
                Button(action: {
                    // 启动连接
                    networkManager.startVPN()
                }) {
                    Text("Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // 停止连接
                    networkManager.stopVPN()
                }) {
                    Text("Stop")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ConnectionStatusCard: View {
    @EnvironmentObject private var networkManager: NetworkExtensionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("Status:")
                    .font(.subheadline)
                Text(networkManager.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            
            if let errorMessage = networkManager.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            
            if networkManager.status == .connected {
                HStack {
                    Text("IP Address:")
                        .font(.subheadline)
                    Text(networkManager.ipAddress ?? "Unknown")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var statusColor: Color {
        switch networkManager.status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .error:
            return .red
        default:
            return .gray
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(NetworkExtensionManager())
    }
}
