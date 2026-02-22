import NetworkExtension
import os

// 定义日志记录器
private let logger = Logger(subsystem: "site.yinmo.terracotta", category: "PacketTunnelProvider")

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var isRunning = false
    private var lastAppliedSettings: TunnelNetworkSettingsSnapshot?
    private var needReapplySettings: Bool = false
    private var reasserting = false
    private var rustInitialized = false
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("startTunnel(): triggered")
        
        // 初始化Rust日志
        if !rustInitialized {
            init_rust_logger("info".cString(using: .utf8)!)
            rustInitialized = true
        }
        
        // 从共享UserDefaults加载配置
        guard let defaults = UserDefaults(suiteName: APP_GROUP_ID),
              let configData = defaults.data(forKey: "VPNConfig") else {
            logger.error("startTunnel() config is nil")
            completionHandler(NSError(domain: "TerracottaError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Configuration is not set"]))
            return
        }
        
        // 将配置数据转换为字符串
        guard let configString = String(data: configData, encoding: .utf8) else {
            logger.error("startTunnel() failed to decode config")
            completionHandler(NSError(domain: "TerracottaError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to decode configuration"]))
            return
        }
        
        // 启动网络实例
        var errPtr: UnsafePointer<CChar>? = nil
        let status = configString.withCString { strPtr in
            return run_network_instance(strPtr, &errPtr)
        }
        
        guard status == 0 else {
            let err = extractRustString(errPtr)
            logger.error("startTunnel() failed to run: \(err ?? "Unknown", privacy: .public)")
            completionHandler(NSError(domain: "TerracottaError", code: 1003, userInfo: [NSLocalizedDescriptionKey: err ?? "Unknown error"]))
            return
        }
        
        // 注册回调
        registerRustStopCallback()
        registerRunningInfoCallback()
        
        // 从配置字符串中提取网络设置
        let tunnelNetworkSettings = extractNetworkSettings(from: configString)
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] (error) in
            guard let self = self else {
                completionHandler(error)
                return
            }
            
            if let error = error {
                logger.error("startTunnel() failed to set tunnel network settings: \(error.localizedDescription)")
                self.stopRustInstance()
                completionHandler(error)
                return
            }
            
            self.isRunning = true
            logger.info("Terracotta tunnel started successfully")
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("stopTunnel(): reason=\(reason.rawValue, privacy: .public)")
        
        stopRustInstance()
        
        isRunning = false
        completionHandler()
    }
    
    private func stopRustInstance() {
        let status = stop_network_instance()
        if status != 0 {
            logger.error("stopRustInstance() failed")
        }
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // 处理来自主应用的消息
        logger.info("Received app message with \(messageData.count) bytes")
        
        guard let messageString = String(data: messageData, encoding: .utf8) else {
            logger.error("Failed to decode message data")
            completionHandler?("Invalid message format".data(using: .utf8))
            return
        }
        
        if messageString.hasPrefix("CREATE_ROOM:") {
            let roomName = String(messageString.dropFirst(12)) // Remove "CREATE_ROOM:" prefix
            var resultPtr: UnsafePointer<CChar>?
            var errPtr: UnsafePointer<CChar>?
            
            let roomNameCString = roomName.cString(using: .utf8)!
            let status = create_room(roomNameCString, &errPtr, &resultPtr)
            
            if status == 0, let resultPtr = resultPtr {
                let roomCode = String(cString: resultPtr)
                free(UnsafeMutableRawPointer(mutating: resultPtr))
                
                logger.info("Successfully created room: \(roomCode)")
                let response = roomCode.data(using: .utf8)
                completionHandler?(response)
            } else if let errPtr = errPtr {
                let errorStr = String(cString: errPtr)
                free(UnsafeMutableRawPointer(mutating: errPtr))
                
                logger.error("Failed to create room: \(errorStr)")
                let response = "ERROR:\(errorStr)".data(using: .utf8)
                completionHandler?(response)
            } else {
                let errorStr = "Unknown error occurred while creating room"
                logger.error("Failed to create room: \(errorStr)")
                let response = "ERROR:\(errorStr)".data(using: .utf8)
                completionHandler?(response)
            }
        } else if messageString.hasPrefix("JOIN_ROOM:") {
            let roomCode = String(messageString.dropFirst(10)) // Remove "JOIN_ROOM:" prefix
            var errPtr: UnsafePointer<CChar>?
            
            let roomCodeCString = roomCode.cString(using: .utf8)!
            let status = join_room(roomCodeCString, &errPtr)
            
            if status == 0 {
                logger.info("Successfully joined room: \(roomCode)")
                let response = "SUCCESS".data(using: .utf8)
                completionHandler?(response)
            } else if let errPtr = errPtr {
                let errorStr = String(cString: errPtr)
                free(UnsafeMutableRawPointer(mutating: errPtr))
                
                logger.error("Failed to join room: \(errorStr)")
                let response = "ERROR:\(errorStr)".data(using: .utf8)
                completionHandler?(response)
            } else {
                let errorStr = "Unknown error occurred while joining room"
                logger.error("Failed to join room: \(errorStr)")
                let response = "ERROR:\(errorStr)".data(using: .utf8)
                completionHandler?(response)
            }
        } else if messageString == "runningInfo" {
            // 获取运行信息
            var infoPtr: UnsafePointer<CChar>?
            var errPtr: UnsafePointer<CChar>?
            
            let status = get_running_info(&infoPtr, &errPtr)
            
            if status == 0, let infoPtr = infoPtr {
                let infoStr = String(cString: infoPtr)
                free(UnsafeMutableRawPointer(mutating: infoPtr))
                
                logger.info("Returning running info")
                let response = infoStr.data(using: .utf8)
                completionHandler?(response)
            } else if let errPtr = errPtr {
                let errorStr = String(cString: errPtr)
                free(UnsafeMutableRawPointer(mutating: errPtr))
                
                logger.error("Failed to get running info: \(errorStr)")
                let response = "ERROR:\(errorStr)".data(using: .utf8)
                completionHandler?(response)
            } else {
                let errorStr = "Unknown error occurred while getting running info"
                logger.error("Failed to get running info: \(errorStr)")
                let response = "ERROR:\(errorStr)".data(using: .utf8)
                completionHandler?(response)
            }
        } else {
            logger.info("Received unknown message type: \(messageString)")
            let response = "Message received".data(using: .utf8)
            completionHandler?(response)
        }
    }
    
    private func extractNetworkSettings(from configString: String) -> NEPacketTunnelNetworkSettings {
        // 解析配置以提取网络设置
        // 这里使用一个简化的实现，可以进一步完善
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // IPv4 设置
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings
        
        // IPv6 设置 (可选)
        let ipv6Settings = NEIPv6Settings(addresses: ["fd42:4242:4242::2"], networkPrefixLength: 64)
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings
        
        // DNS 设置
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dnsSettings
        
        // MTU 设置
        settings.mtu = 1380  // 使用较小的MTU避免分片问题
        
        return settings
    }
    
    private func registerRustStopCallback() {
        // 注册Rust停止回调
        let rustStopCallback: @convention(c) () -> Void = { [weak self] in
            self?.handleRustStop()
        }
        var regErrPtr: UnsafePointer<CChar>? = nil
        let regRet = register_stop_callback(rustStopCallback, &regErrPtr)
        if regRet != 0 {
            let regErr = extractRustString(regErrPtr)
            logger.error("registerRustStopCallback() failed: \(regErr ?? "Unknown", privacy: .public)")
        } else {
            logger.info("registerRustStopCallback() registered")
        }
    }
    
    private func registerRunningInfoCallback() {
        // 注册运行信息回调
        let infoChangedCallback: @convention(c) () -> Void = { [weak self] in
            self?.handleRunningInfoChanged()
        }
        var errPtr: UnsafePointer<CChar>? = nil
        let ret = register_running_info_callback(infoChangedCallback, &errPtr)
        if ret != 0 {
            let err = extractRustString(errPtr)
            logger.error("registerRunningInfoCallback() failed: \(err ?? "Unknown", privacy: .public)")
        } else {
            logger.info("registerRunningInfoCallback() registered")
        }
    }
    
    private func handleRustStop() {
        // 处理由Rust层触发的停止事件
        logger.error("handleRustStop(): triggered from Rust layer")
        
        var msgPtr: UnsafePointer<CChar>? = nil
        var errPtr: UnsafePointer<CChar>? = nil
        let ret = get_latest_error_msg(&msgPtr, &errPtr)
        if ret == 0, let msg = extractRustString(msgPtr) {
            logger.error("handleRustStop(): \(msg, privacy: .public)")
            // 在主线程上取消隧道
            DispatchQueue.main.async {
                self.cancelTunnelWithError(NSError(domain: "TerracottaError", code: 999, userInfo: [NSLocalizedDescriptionKey: msg]))
            }
        } else if let err = extractRustString(errPtr) {
            logger.error("handleRustStop() failed to get latest error: \(err, privacy: .public)")
            DispatchQueue.main.async {
                self.cancelTunnelWithError(NSError(domain: "TerracottaError", code: 998, userInfo: [NSLocalizedDescriptionKey: err]))
            }
        }
    }
    
    private func handleRunningInfoChanged() {
        logger.info("handleRunningInfoChanged(): triggered")
        // 可以在此处更新网络设置
        enqueueSettingsUpdate()
    }
    
    private func enqueueSettingsUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.reasserting {
                logger.info("enqueueSettingsUpdate() update in progress, waiting")
                self.needReapplySettings = true
                return
            }
            logger.info("enqueueSettingsUpdate() starting settings update")
            self.applyNetworkSettings() { error in
                guard let error = error else { return }
                logger.info("enqueueSettingsUpdate() failed with error: \(error)")
            }
        }
    }
    
    private func applyNetworkSettings(_ completion: @escaping ((any Error)?) -> Void) {
        guard !reasserting else {
            logger.error("applyNetworkSettings() still in progress")
            completion(NSError(domain: "TerracottaError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Settings update in progress"]))
            return
        }
        
        reasserting = true
        Thread.sleep(forTimeInterval: 0.5) // 0.5秒延迟
        needReapplySettings = false
        
        // 创建新的网络设置
        let settings = extractNetworkSettings(from: "") // 在实际实现中，可以从当前配置获取设置
        let newSnapshot = snapshotSettings(settings)
        let wrappedCompletion: (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(error as? any Error)
                    return
                }
                
                if error == nil {
                    self.lastAppliedSettings = newSnapshot
                }
                
                completion(error as? any Error)
                self.reasserting = false
                if self.needReapplySettings {
                    self.needReapplySettings = false
                    self.applyNetworkSettings(completion)
                }
            }
        }
        
        if newSnapshot == lastAppliedSettings {
            logger.info("applyNetworkSettings() new settings are exactly the same as last applied, skipping")
            wrappedCompletion(nil)
            return
        }
        
        logger.info("applyNetworkSettings() applying settings")
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else {
                wrappedCompletion(error)
                return
            }
            
            if let error {
                logger.error("applyNetworkSettings() failed to setTunnelNetworkSettings: \(error, privacy: .public)")
                wrappedCompletion(error)
                return
            }
            
            // 检查是否需要设置TUN FD
            if let tunFd = self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
                var errPtr: UnsafePointer<CChar>? = nil
                let ret = set_tun_fd(tunFd, &errPtr)
                guard ret == 0 else {
                    let err = extractRustString(errPtr)
                    logger.error("applyNetworkSettings() failed to set tun fd to \(tunFd): \(err, privacy: .public)")
                    wrappedCompletion(NSError(domain: "TerracottaError", code: 997, userInfo: [NSLocalizedDescriptionKey: err ?? "Failed to set TUN fd"]))
                    return
                }
                logger.info("applyNetworkSettings() successfully set TUN fd to \(tunFd)")
            } else {
                logger.warning("applyNetworkSettings() no available tun fd")
            }
            
            logger.info("applyNetworkSettings() settings applied")
            wrappedCompletion(nil)
        }
    }
    
    private func extractRustString(_ ptr: UnsafePointer<CChar>?) -> String? {
        guard let ptr = ptr else { return nil }
        let str = String(cString: ptr)
        // 释放Rust分配的字符串
        free(UnsafeMutableRawPointer(mutating: ptr))
        return str
    }
    
    // 这个辅助结构体用于比较网络设置
    struct TunnelNetworkSettingsSnapshot: Equatable {
        let ipv4Addresses: [String]
        let ipv6Addresses: [String]
        let dnsServers: [String]
        let mtu: Int
    }
    
    private func snapshotSettings(_ settings: NEPacketTunnelNetworkSettings) -> TunnelNetworkSettingsSnapshot {
        let ipv4Addresses = settings.ipv4Settings?.addresses ?? []
        let ipv6Addresses = settings.ipv6Settings?.addresses ?? []
        let dnsServers = settings.dnsSettings?.servers ?? []
        let mtu = settings.mtu?.intValue ?? 1500
        
        return TunnelNetworkSettingsSnapshot(
            ipv4Addresses: ipv4Addresses,
            ipv6Addresses: ipv6Addresses,
            dnsServers: dnsServers,
            mtu: mtu
        )
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        logger.info("sleep(): called")
        completionHandler()
    }
    
    override func wake() {
        logger.info("wake(): called")
    }
}
