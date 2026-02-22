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
                DispatchQueue.main.async {
                    self?.status = .error
                    self?.errorMessage = "Failed to load VPN manager"
                }
                return
            }
            
            do {
                // 传递配置信息到VPN扩展
                var startOptions: [String: NSObject] = [:]
                startOptions["action"] = "start" as NSString
                
                try vpnManager.connection.startVPNTunnel(options: startOptions)
                DispatchQueue.main.async {
                    self.status = .connecting
                    self.errorMessage = nil
                }
                self.logger.info("VPN tunnel started successfully")
            } catch {
                DispatchQueue.main.async {
                    self.status = .error
                    self.errorMessage = "Failed to start VPN: \(error.localizedDescription)"
                }
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
                DispatchQueue.main.async {
                    self.status = .disconnected
                    self.errorMessage = nil
                    self.ipAddress = nil
                }
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
        
        // 通过共享UserDefaults和Darwin通知与网络扩展通信
        if let defaults = UserDefaults(suiteName: APP_GROUP_ID) {
            defaults.set("runningInfo", forKey: "VPNMessageToExtension")
            defaults.synchronize()
            
            // 发送 Darwin 通知以提醒扩展检查新消息
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("com.terracotta.networkextension.message" as CFString),
                nil,
                nil,
                true
            )
        }
    }
    
    func sendMessage(_ message: String, completion: @escaping (Data?) -> Void) {
        // 使用 Darwin Notification 进行 App 和 Network Extension 之间的通信
        guard let vpnManager = vpnManager else {
            completion(nil)
            return
        }
        
        // 将消息保存到共享UserDefaults，网络扩展会定期检查
        if let defaults = UserDefaults(suiteName: APP_GROUP_ID) {
            defaults.set(message, forKey: "VPNMessageToExtension")
            defaults.synchronize()
            
            // 发送 Darwin 通知以提醒扩展检查新消息
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("com.terracotta.networkextension.message" as CFString),
                nil,
                nil,
                true
            )
            
            // 模拟响应 - 网络扩展会将响应写入另一个键
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 2秒超时
                if let response = defaults.string(forKey: "VPNMessageFromExtension") {
                    completion(response.data(using: .utf8))
                } else {
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }
    
    deinit {
        if isMonitoring {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
