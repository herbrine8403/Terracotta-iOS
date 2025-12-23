//
//  PacketTunnelProvider.swift
//  TerracottaNetworkExtension
//
//  Created for Terracotta iOS adaptation
//

import NetworkExtension
import os.log
import Foundation

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var tunnelConnection: NEPacketTunnelFlow?
    private var zeroTierNode: ZeroTierNodeWrapper?
    private let logger = Logger(subsystem: "net.burningtnt.terracotta", category: "PacketTunnel")
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting packet tunnel")
        
        // 获取网络配置
        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let networkId = providerConfiguration["networkId"] as? String,
              let nodeId = providerConfiguration["nodeId"] as? String else {
            logger.error("Invalid tunnel configuration")
            completionHandler(TerracottaError.invalidConfiguration)
            return
        }
        
        // 初始化 ZeroTier 节点
        zeroTierNode = ZeroTierNodeWrapper()
        
        // 设置虚拟网络接口
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        tunnelSettings.mtu = 2800
        
        // 配置 DNS
        tunnelSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        
        // 配置代理
        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = false
        proxySettings.httpsEnabled = false
        tunnelSettings.proxySettings = proxySettings
        
        // 应用网络设置
        self.setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to set tunnel network settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            // 启动 ZeroTier 节点
            self?.startZeroTierNode(networkId: networkId, nodeId: nodeId) { error in
                if let error = error {
                    self?.logger.error("Failed to start ZeroTier node: \(error.localizedDescription)")
                    completionHandler(error)
                } else {
                    self?.logger.info("Packet tunnel started successfully")
                    completionHandler(nil)
                }
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping packet tunnel with reason: \(reason.rawValue)")
        
        // 停止 ZeroTier 节点
        zeroTierNode?.stop()
        zeroTierNode = nil
        
        // 清理连接
        tunnelConnection = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // 处理来自主应用的消息
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler(nil)
            return
        }
        
        logger.info("Received app message: \(message)")
        
        // 解析消息并执行相应操作
        if message.hasPrefix("JOIN_NETWORK:") {
            let networkId = String(message.dropFirst("JOIN_NETWORK:".count))
            joinNetwork(networkId: networkId) { success in
                let response = success ? "SUCCESS" : "FAILED"
                completionHandler(response.data(using: .utf8))
            }
        } else if message.hasPrefix("LEAVE_NETWORK:") {
            let networkId = String(message.dropFirst("LEAVE_NETWORK:".count))
            leaveNetwork(networkId: networkId) { success in
                let response = success ? "SUCCESS" : "FAILED"
                completionHandler(response.data(using: .utf8))
            }
        } else if message == "GET_STATUS" {
            getStatus { status in
                completionHandler(status.data(using: .utf8))
            }
        } else {
            completionHandler(nil)
        }
    }
    
    override func sleep() {
        logger.info("Packet tunnel going to sleep")
    }
    
    override func wake() {
        logger.info("Packet tunnel waking up")
    }
    
    // MARK: - Private Methods
    
    private func startZeroTierNode(networkId: String, nodeId: String, completion: @escaping (Error?) -> Void) {
        zeroTierNode?.start(nodeId: nodeId) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            self?.zeroTierNode?.joinNetwork(networkId: networkId) { error in
                completion(error)
            }
        }
    }
    
    private func joinNetwork(networkId: String, completion: @escaping (Bool) -> Void) {
        zeroTierNode?.joinNetwork(networkId: networkId) { error in
            completion(error == nil)
        }
    }
    
    private func leaveNetwork(networkId: String, completion: @escaping (Bool) -> Void) {
        zeroTierNode?.leaveNetwork(networkId: networkId) { error in
            completion(error == nil)
        }
    }
    
    private func getStatus(completion: @escaping (String) -> Void) {
        guard let node = zeroTierNode else {
            completion("STOPPED")
            return
        }
        
        node.getStatus { status in
            completion(status)
        }
    }
}

// MARK: - ZeroTier Node Wrapper

class ZeroTierNodeWrapper {
    private var isInitialized = false
    private let logger = Logger(subsystem: "net.burningtnt.terracotta", category: "ZeroTierNode")
    
    func start(nodeId: String, completion: @escaping (Error?) -> Void) {
        logger.info("Starting ZeroTier node with ID: \(nodeId)")
        
        // 调用原生 ZeroTier 启动函数
        guard terracotta_start_node(nodeId) else {
            completion(TerracottaError.nodeStartFailed)
            return
        }
        
        isInitialized = true
        completion(nil)
    }
    
    func stop() {
        logger.info("Stopping ZeroTier node")
        
        if isInitialized {
            terracotta_stop_node()
            isInitialized = false
        }
    }
    
    func joinNetwork(networkId: String, completion: @escaping (Error?) -> Void) {
        guard isInitialized else {
            completion(TerracottaError.nodeNotInitialized)
            return
        }
        
        logger.info("Joining network: \(networkId)")
        
        if terracotta_join_network(networkId) {
            completion(nil)
        } else {
            completion(TerracottaError.networkJoinFailed)
        }
    }
    
    func leaveNetwork(networkId: String, completion: @escaping (Error?) -> Void) {
        guard isInitialized else {
            completion(TerracottaError.nodeNotInitialized)
            return
        }
        
        logger.info("Leaving network: \(networkId)")
        
        if terracotta_leave_network(networkId) {
            completion(nil)
        } else {
            completion(TerracottaError.networkLeaveFailed)
        }
    }
    
    func getStatus(completion: @escaping (String) -> Void) {
        guard isInitialized else {
            completion("NOT_INITIALIZED")
            return
        }
        
        let status = terracotta_get_node_status()
        completion(String(cString: status))
    }
}

// MARK: - Error Types

enum TerracottaError: Error, LocalizedError {
    case invalidConfiguration
    case nodeStartFailed
    case nodeNotInitialized
    case networkJoinFailed
    case networkLeaveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid tunnel configuration"
        case .nodeStartFailed:
            return "Failed to start ZeroTier node"
        case .nodeNotInitialized:
            return "ZeroTier node not initialized"
        case .networkJoinFailed:
            return "Failed to join network"
        case .networkLeaveFailed:
            return "Failed to leave network"
        }
    }
}