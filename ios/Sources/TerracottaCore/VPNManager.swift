//
//  VPNManager.swift
//  TerracottaCore
//
//  Created for Terracotta iOS adaptation
//

import NetworkExtension
import Combine
import Foundation

public class VPNManager: ObservableObject {
    @Published public var connectionStatus: VPNStatus = .disconnected
    @Published public var currentNetwork: String?
    
    private var manager: NETunnelProviderManager?
    private let logger = Logger(subsystem: "net.burningtnt.terracotta", category: "VPNManager")
    
    public enum VPNStatus {
        case disconnected
        case connecting
        case connected
        case disconnecting
        case reconnecting
        
        var isConnected: Bool {
            switch self {
            case .connected:
                return true
            default:
                return false
            }
        }
    }
    
    public init() {
        loadProviderManager()
    }
    
    // MARK: - Public Methods
    
    public func connect(networkId: String, nodeId: String) async throws {
        logger.info("Connecting to VPN with network ID: \(networkId)")
        
        await MainActor.run {
            self.connectionStatus = .connecting
        }
        
        do {
            try await setupAndStartVPN(networkId: networkId, nodeId: nodeId)
            
            await MainActor.run {
                self.connectionStatus = .connected
                self.currentNetwork = networkId
            }
            
            logger.info("VPN connected successfully")
        } catch {
            await MainActor.run {
                self.connectionStatus = .disconnected
            }
            
            logger.error("VPN connection failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func disconnect() async {
        logger.info("Disconnecting from VPN")
        
        await MainActor.run {
            self.connectionStatus = .disconnecting
        }
        
        manager?.connection.stopVPNTunnel()
        
        await MainActor.run {
            self.connectionStatus = .disconnected
            self.currentNetwork = nil
        }
        
        logger.info("VPN disconnected")
    }
    
    public func getStatus() async -> String {
        guard let manager = manager else {
            return "MANAGER_UNAVAILABLE"
        }
        
        switch manager.connection.status {
        case .disconnected:
            return "DISCONNECTED"
        case .connecting:
            return "CONNECTING"
        case .connected:
            return "CONNECTED"
        case .disconnecting:
            return "DISCONNECTING"
        case .reasserting:
            return "RECONNECTING"
        case .invalid:
            return "INVALID"
        @unknown default:
            return "UNKNOWN"
        }
    }
    
    public func sendMessageToProvider(_ message: String) async -> String? {
        guard let session = manager?.connection as? NETunnelProviderSession else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(message.data(using: .utf8)!) { data in
                    if let data = data {
                        continuation.resume(returning: String(data: data, encoding: .utf8))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } catch {
                logger.error("Failed to send message to provider: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadProviderManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Failed to load provider managers: \(error.localizedDescription)")
                return
            }
            
            self.manager = managers?.first ?? NETunnelProviderManager()
            
            // 监听连接状态变化
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.connectionStatusChanged),
                name: .NEVPNStatusDidChange,
                object: self.manager?.connection
            )
        }
    }
    
    private func setupAndStartVPN(networkId: String, nodeId: String) async throws {
        guard let manager = manager else {
            throw VPNError.managerNotAvailable
        }
        
        // 配置协议
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = "net.burningtnt.terracotta.TerracottaNetworkExtension"
        protocolConfiguration.serverAddress = "Terracotta VPN"
        protocolConfiguration.providerConfiguration = [
            "networkId": networkId,
            "nodeId": nodeId
        ]
        
        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = "陶瓦联机"
        manager.isEnabled = true
        
        // 保存配置
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // 启动 VPN
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try manager.connection.startVPNTunnel()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    @objc private func connectionStatusChanged() {
        guard let manager = manager else { return }
        
        Task {
            let status = await getStatus()
            
            await MainActor.run {
                switch status {
                case "CONNECTED":
                    self.connectionStatus = .connected
                case "CONNECTING":
                    self.connectionStatus = .connecting
                case "DISCONNECTING":
                    self.connectionStatus = .disconnecting
                case "RECONNECTING":
                    self.connectionStatus = .reconnecting
                default:
                    self.connectionStatus = .disconnected
                    self.currentNetwork = nil
                }
            }
        }
    }
}

// MARK: - Error Types

public enum VPNError: Error, LocalizedError {
    case managerNotAvailable
    case configurationFailed
    case connectionFailed
    
    public var errorDescription: String? {
        switch self {
        case .managerNotAvailable:
            return "VPN manager not available"
        case .configurationFailed:
            return "VPN configuration failed"
        case .connectionFailed:
            return "VPN connection failed"
        }
    }
}