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
    
    private let logger = Logger(subsystem: "site.yinmo.terracotta", category: "NetworkExtensionManager")
    
    init() {
        loadVPNManager()
    }
    
    func startVPN(options: TerracottaOptions? = nil) {
        // 保存配置到共享UserDefaults
        if let options = options, let defaults = UserDefaults(suiteName: APP_GROUP_ID) {
            do {
                let data = try JSONEncoder().encode(options)
                defaults.set(data, forKey: "VPNConfig")
                defaults.synchronize()
            } catch {
                logger.error("Failed to save VPN config: \(error.localizedDescription)")
            }
        }
        
        loadVPNManager { [weak self] in
            guard let self = self, let vpnManager = self.vpnManager else {
                self?.status = .error
                self?.errorMessage = "Failed to load VPN manager"
                return
            }
            
            do {
                // 传递配置信息到VPN扩展
                var startOptions: [String: NSObject] = [:]
                startOptions["action"] = "start" as NSString
                
                try vpnManager.connection.startVPNTunnel(options: startOptions)
                self.status = .connecting
                self.errorMessage = nil
                self.logger.info("VPN tunnel started successfully")
            } catch {
                self.status = .error
                self.errorMessage = "Failed to start VPN: \(error.localizedDescription)"
                self.logger.error("Failed to start VPN: \(error.localizedDescription)")
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
                self.logger.info("VPN tunnel stopped")
            }
        }
    }
    
    func loadVPNManager(completion: (() -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            if let error = error {
                self?.logger.error("Failed to load VPN managers: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.status = .error
                    self?.errorMessage = "Failed to load VPN managers: \(error.localizedDescription)"
                    completion?()
                }
                return
            }
            
            if let manager = managers?.first {
                DispatchQueue.main.async {
                    self?.vpnManager = manager
                    self?.updateStatus(from: manager.connection.status)
                    self?.startMonitoringStatus()
                    completion?()
                }
            } else {
                DispatchQueue.main.async {
                    self?.createVPNManager(completion: completion)
                }
            }
        }
    }
    
    private func createVPNManager(completion: (() -> Void)? = nil) {
        let manager = NETunnelProviderManager()
        
        // 配置 VPN 协议
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = "site.yinmo.terracotta.TerracottaNetworkExtension"
        protocolConfiguration.serverAddress = "Terracotta"
        
        // 设置提供商配置
        protocolConfiguration.providerConfiguration = [
            "server_address": "Terracotta",
            "version": "1.0"
        ]
        
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "Terracotta"
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] (error) in
            if let error = error {
                self?.logger.error("Failed to save VPN manager: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.status = .error
                    self?.errorMessage = "Failed to save VPN manager: \(error.localizedDescription)"
                    completion?()
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.vpnManager = manager
                self?.status = .disconnected
                self?.startMonitoringStatus()
                completion?()
            }
        }
    }
    
    private func startMonitoringStatus() {
        guard !isMonitoring, let vpnManager = vpnManager else {
            return
        }
        
        isMonitoring = true
        
        // 移除之前的观察者
        NotificationCenter.default.removeObserver(
            self,
            name: .NEVPNStatusDidChange,
            object: vpnManager.connection
        )
        
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
        DispatchQueue.main.async {
            switch vpnStatus {
            case .invalid:
                self.status = .error
                self.errorMessage = "VPN configuration is invalid"
                self.logger.error("VPN status is invalid")
            case .disconnected:
                self.status = .disconnected
                self.ipAddress = nil
                self.logger.info("VPN disconnected")
            case .connecting:
                self.status = .connecting
                self.logger.info("VPN connecting")
            case .connected:
                self.status = .connected
                self.logger.info("VPN connected")
                // 尝试获取运行信息
                self.fetchRunningInfo()
            case .reasserting:
                self.status = .connecting
                self.logger.info("VPN reasserting")
            case .disconnecting:
                self.status = .disconnected
                self.logger.info("VPN disconnecting")
            @unknown default:
                self.status = .error
                self.errorMessage = "Unknown VPN status"
                self.logger.error("VPN unknown status")
            }
        }
    }
    
    private func fetchRunningInfo() {
        // 发送消息到网络扩展获取运行信息
        guard let vpnManager = vpnManager,
              vpnManager.connection.status == .connected else {
            return
        }
        
        let message = "runningInfo".data(using: .utf8) ?? Data()
        vpnManager.connection.sendProviderMessage(message) { [weak self] response in
            if let responseData = response as? Data,
               let responseString = String(data: responseData, encoding: .utf8) {
                self?.logger.info("Received running info: \(responseString)")
                // 在这里可以解析运行信息并更新UI
            }
        }
    }
    
    // 发送消息到VPN扩展
    func sendMessage(_ message: String, completion: @escaping (Data?) -> Void) {
        guard let vpnManager = vpnManager else {
            completion(nil)
            return
        }
        
        let messageData = message.data(using: .utf8) ?? Data()
        
        // 使用正确的方法发送消息到网络扩展
        vpnManager.connection.sendProviderMessage(messageData) { response in
            completion(response)
        }
    }
    
    deinit {
        if isMonitoring {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
