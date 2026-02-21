import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var tunnelFileDescriptor: Int32 = -1
    private var isRunning = false
    private var errorMessage: String?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting Terracotta tunnel", log: OSLog.default, type: .info)
        
        // 配置 VPN 隧道
        let tunnelNetworkSettings = createTunnelNetworkSettings()
        setTunnelNetworkSettings(tunnelNetworkSettings) {
            [weak self] (error) in
            guard let self = self else {
                return
            }
            
            if let error = error {
                os_log("Failed to set tunnel network settings: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            // 启动 EasyTier 网络实例
            self.startEasyTier {
                [weak self] (error) in
                guard let self = self else {
                    return
                }
                
                if let error = error {
                    os_log("Failed to start EasyTier: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }
                
                self.isRunning = true
                os_log("Terracotta tunnel started successfully", log: OSLog.default, type: .info)
                completionHandler(nil)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping Terracotta tunnel", log: OSLog.default, type: .info)
        
        // 停止 EasyTier 网络实例
        stopEasyTier {
            [weak self] in
            guard let self = self else {
                completionHandler()
                return
            }
            
            self.isRunning = false
            os_log("Terracotta tunnel stopped successfully", log: OSLog.default, type: .info)
            completionHandler()
        }
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // 处理来自主应用的消息
        os_log("Received app message: %{public}s", log: OSLog.default, type: .info, messageData.count)
        
        if let completionHandler = completionHandler {
            let response = "Message received".data(using: .utf8)
            completionHandler(response)
        }
    }
    
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // 配置 IPv4 设置
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        ipv4Settings.excludedRoutes = []
        settings.ipv4Settings = ipv4Settings
        
        // 配置 DNS 设置
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dnsSettings.searchDomains = []
        settings.dnsSettings = dnsSettings
        
        // 配置 MTU
        settings.mtu = 1500
        
        return settings
    }
    
    private func startEasyTier(completionHandler: @escaping (Error?) -> Void) {
        // 读取配置
        guard let config = loadConfig() else {
            let error = NSError(domain: "TerracottaErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load config"])
            completionHandler(error)
            return
        }
        
        // 调用 FFI 函数启动网络实例
        var errMsg: UnsafePointer<CChar>? = nil
        let status = run_network_instance(config, &errMsg)
        
        if status == 0 {
            completionHandler(nil)
        } else if let errMsg = errMsg {
            let errorMessage = String(cString: errMsg)
            let error = NSError(domain: "TerracottaErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            completionHandler(error)
        } else {
            let error = NSError(domain: "TerracottaErrorDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to start network instance"])
            completionHandler(error)
        }
    }
    
    private func stopEasyTier(completionHandler: @escaping () -> Void) {
        // 调用 FFI 函数停止网络实例
        let status = stop_network_instance()
        
        if status == 0 {
            os_log("EasyTier stopped successfully", log: OSLog.default, type: .info)
        } else {
            os_log("Failed to stop EasyTier", log: OSLog.default, type: .error)
        }
        
        completionHandler()
    }
    
    private func loadConfig() -> UnsafePointer<CChar>? {
        // 从 UserDefaults 加载配置
        guard let userDefaults = UserDefaults(suiteName: APP_GROUP_ID) else {
            return nil
        }
        
        let configString = userDefaults.string(forKey: "config") ?? ""
        return strdup(configString)
    }
}
