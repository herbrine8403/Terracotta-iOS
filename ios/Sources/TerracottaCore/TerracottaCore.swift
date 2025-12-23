//
//  TerracottaCore.swift
//  TerracottaCore
//
//  Main entry point for Terracotta iOS core functionality
//

import Foundation
import Combine
import os.log

public class TerracottaCore: ObservableObject {
    public static let shared = TerracottaCore()
    
    @Published public var currentState: TerracottaState = .waiting
    @Published public var errorMessage: String?
    @Published public var roomInfo: RoomInfo?
    @Published public var nodeInfo: NodeInfo?
    
    private let logger = Logger(subsystem: "net.burningtnt.terracotta", category: "TerracottaCore")
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNativeCallbacks()
        initializeCore()
    }
    
    // MARK: - Public Methods
    
    public func createRoom(roomCode: String? = nil, playerName: String) async throws -> String {
        logger.info("Creating room with player name: \(playerName)")
        
        let code = roomCode ?? generateRoomCode()
        
        let success = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = terracotta_create_room(code, playerName)
                continuation.resume(returning: result)
            }
        }
        
        guard success else {
            let error = getErrorMessage()
            logger.error("Failed to create room: \(error)")
            throw TerracottaError.roomCreationFailed(error)
        }
        
        logger.info("Room created successfully with code: \(code)")
        return code
    }
    
    public func joinRoom(roomCode: String, playerName: String) async throws {
        logger.info("Joining room: \(roomCode) with player name: \(playerName)")
        
        let success = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = terracotta_join_room(roomCode, playerName)
                continuation.resume(returning: result)
            }
        }
        
        guard success else {
            let error = getErrorMessage()
            logger.error("Failed to join room: \(error)")
            throw TerracottaError.roomJoinFailed(error)
        }
        
        logger.info("Room joined successfully")
    }
    
    public func leaveRoom() async {
        logger.info("Leaving room")
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                terracotta_leave_room()
                continuation.resume()
            }
        }
        
        logger.info("Room left successfully")
    }
    
    public func startNode(nodeId: String) async throws {
        logger.info("Starting ZeroTier node: \(nodeId)")
        
        let success = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = terracotta_start_node(nodeId)
                continuation.resume(returning: result)
            }
        }
        
        guard success else {
            let error = getErrorMessage()
            logger.error("Failed to start node: \(error)")
            throw TerracottaError.nodeStartFailed(error)
        }
        
        logger.info("Node started successfully")
        await updateNodeInfo()
    }
    
    public func stopNode() async {
        logger.info("Stopping ZeroTier node")
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                terracotta_stop_node()
                continuation.resume()
            }
        }
        
        logger.info("Node stopped successfully")
    }
    
    public func joinNetwork(networkId: String) async throws {
        logger.info("Joining network: \(networkId)")
        
        let success = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = terracotta_join_network(networkId)
                continuation.resume(returning: result)
            }
        }
        
        guard success else {
            let error = getErrorMessage()
            logger.error("Failed to join network: \(error)")
            throw TerracottaError.networkJoinFailed(error)
        }
        
        logger.info("Network joined successfully")
    }
    
    public func setWaitingState() async {
        logger.info("Setting waiting state")
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                terracotta_set_waiting_state()
                continuation.resume()
            }
        }
    }
    
    public func setScanningState(roomCode: String? = nil, playerName: String? = nil) async {
        logger.info("Setting scanning state")
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                terracotta_set_scanning_state(roomCode, playerName)
                continuation.resume()
            }
        }
    }
    
    public func getVersion() -> String {
        return String(cString: terracotta_get_version())
    }
    
    // MARK: - Private Methods
    
    private func initializeCore() {
        logger.info("Initializing Terracotta core")
        
        // Initialize logging
        let logPath = getDocumentsDirectory().appendingPathComponent("terracotta.log").path
        terracotta_init_logging(logPath)
        
        logger.info("Terracotta core initialized")
    }
    
    private func setupNativeCallbacks() {
        // Set up state callback
        terracotta_set_state_callback { [weak self] stateString in
            Task { @MainActor in
                self?.handleStateChange(stateString)
            }
        }
        
        // Set up error callback
        terracotta_set_error_callback { [weak self] errorString in
            Task { @MainActor in
                self?.handleError(errorString)
            }
        }
        
        // Set up log callback
        terracotta_set_log_callback { [weak self] logString in
            self?.logger.info("\(logString)")
        }
    }
    
    private func handleStateChange(_ stateString: String) {
        logger.info("State changed: \(stateString)")
        
        guard let data = stateString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stateString = json["state"] as? String else {
            return
        }
        
        let newState = TerracottaState(rawValue: stateString) ?? .waiting
        currentState = newState
        
        // Update room info if available
        if let roomCode = json["room"] as? String {
            roomInfo = RoomInfo(roomCode: roomCode, isHost: currentState.isHost)
        }
    }
    
    private func handleError(_ errorString: String) {
        logger.error("Error occurred: \(errorString)")
        errorMessage = errorString
    }
    
    private func getErrorMessage() -> String {
        return String(cString: terracotta_get_error_message())
    }
    
    private func generateRoomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<5).map { _ in characters.randomElement()! })
        return "U/\(code)"
    }
    
    private func updateNodeInfo() async {
        var nodeInfoStruct = terracotta_node_info_t()
        
        let success = withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = terracotta_get_node_info(&nodeInfoStruct)
                continuation.resume(returning: result)
            }
        }
        
        if success {
            await MainActor.run {
                self.nodeInfo = NodeInfo(
                    networkId: String(cString: nodeInfoStruct.network_id),
                    nodeId: String(cString: nodeInfoStruct.node_id),
                    isOnline: nodeInfoStruct.is_online,
                    port: nodeInfoStruct.port
                )
            }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

// MARK: - Data Models

public struct TerracottaState: Equatable {
    public let rawValue: String
    
    public static let waiting = TerracottaState(rawValue: "waiting")
    public static let hostScanning = TerracottaState(rawValue: "host-scanning")
    public static let hostStarting = TerracottaState(rawValue: "host-starting")
    public static let hostOk = TerracottaState(rawValue: "host-ok")
    public static let guestConnecting = TerracottaState(rawValue: "guest-connecting")
    public static let guestStarting = TerracottaState(rawValue: "guest-starting")
    public static let guestOk = TerracottaState(rawValue: "guest-ok")
    public static let exception = TerracottaState(rawValue: "exception")
    
    public var isHost: Bool {
        return rawValue.hasPrefix("host")
    }
    
    public var isGuest: Bool {
        return rawValue.hasPrefix("guest")
    }
    
    public var isConnected: Bool {
        return self == .hostOk || self == .guestOk
    }
}

public struct RoomInfo {
    public let roomCode: String
    public let isHost: Bool
    public let playerCount: Int
    public let serverAddress: String?
    public let serverPort: Int?
    
    init(roomCode: String, isHost: Bool, playerCount: Int = 0, serverAddress: String? = nil, serverPort: Int? = nil) {
        self.roomCode = roomCode
        self.isHost = isHost
        self.playerCount = playerCount
        self.serverAddress = serverAddress
        self.serverPort = serverPort
    }
}

public struct NodeInfo {
    public let networkId: String
    public let nodeId: String
    public let isOnline: Bool
    public let port: Int
}

// MARK: - Error Types

public enum TerracottaError: Error, LocalizedError {
    case nodeStartFailed(String)
    case networkJoinFailed(String)
    case roomCreationFailed(String)
    case roomJoinFailed(String)
    case invalidParameter(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .nodeStartFailed(let message):
            return "Failed to start node: \(message)"
        case .networkJoinFailed(let message):
            return "Failed to join network: \(message)"
        case .roomCreationFailed(let message):
            return "Failed to create room: \(message)"
        case .roomJoinFailed(let message):
            return "Failed to join room: \(message)"
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}