import Foundation
import NetworkExtension
import os
import TerracottaShared

class NetworkExtensionManager: ObservableObject {
    @Published var status: ConnectionStatus = .disconnected
    @Published var errorMessage: String? = nil
    @Published var ipAddress: String? = nil
    
    private var vpnManager: NETunnelProviderManager?
    private var isMonitoring = false
    
    init() {
        loadVPNManager()
    }
    
    func startVPN() {
        loadVPNManager { [weak self] in
            guard let self = self, let vpnManager = self.vpnManager else {
                self?.status = .error
                self?.errorMessage = "Failed to load VPN manager"
                return
            }
            
            do {
                try vpnManager.connection.startVPNTunnel(options: nil)
                self.status = .connecting
                self.errorMessage = nil
            } catch {
                self.status = .error
                self.errorMessage = "Failed to start VPN: \(error.localizedDescription)"
                os_log("Failed to start VPN: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
            }
        }
    }
    
    func stopVPN() {
        loadVPNManager { [weak self] in
            guard let self = self, let vpnManager = self.vpnManager else {
                return
            }
            
            if vpnManager.connection.status == .connected || vpnManager.connection.status == .connecting {
                vpnManager.connection.stopVPNTunnel()
                self.status = .disconnected
                self.errorMessage = nil
                self.ipAddress = nil
            }
        }
    }
    
    func loadVPNManager(completion: (() -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            if let error = error {
                os_log("Failed to load VPN managers: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
                self?.status = .error
                self?.errorMessage = "Failed to load VPN managers"
                completion?()
                return
            }
            
            if let manager = managers?.first {
                self?.vpnManager = manager
                self?.updateStatus(from: manager.connection.status)
                self?.startMonitoringStatus()
            } else {
                self?.createVPNManager(completion: completion)
            }
        }
    }
    
    private func createVPNManager(completion: (() -> Void)? = nil) {
        let manager = NETunnelProviderManager()
        
        // 配置 VPN 协议
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = "site.yinmo.terracotta.TerracottaNetworkExtension"
        protocolConfiguration.serverAddress = "localhost"
        
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "Terracotta"
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] (error) in
            if let error = error {
                os_log("Failed to save VPN manager: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
                self?.status = .error
                self?.errorMessage = "Failed to save VPN manager"
                completion?()
                return
            }
            
            self?.vpnManager = manager
            self?.status = .disconnected
            self?.startMonitoringStatus()
            completion?()
        }
    }
    
    private func startMonitoringStatus() {
        guard !isMonitoring, let vpnManager = vpnManager else {
            return
        }
        
        isMonitoring = true
        
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: vpnManager.connection,
            queue: OperationQueue.main
        ) { [weak self] (notification) in
            guard let self = self, let vpnConnection = notification.object as? NEVPNConnection else {
                return
            }
            
            self.updateStatus(from: vpnConnection.status)
        }
    }
    
    private func updateStatus(from vpnStatus: NEVPNStatus) {
        switch vpnStatus {
        case .disconnected:
            status = .disconnected
            ipAddress = nil
        case .connecting:
            status = .connecting
        case .connected:
            status = .connected
            // 这里可以获取 IP 地址，需要从网络扩展中获取
        case .reasserting:
            status = .connecting
        case .disconnecting:
            status = .disconnected
        case .invalid:
            status = .error
            errorMessage = "VPN configuration is invalid"
        @unknown default:
            status = .error
            errorMessage = "Unknown VPN status"
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
