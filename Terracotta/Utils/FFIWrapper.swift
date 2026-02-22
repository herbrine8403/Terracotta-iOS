import Foundation
import NetworkExtension
import os
import TerracottaShared

// 通过NetworkExtensionManager访问Rust FFI函数
// 这些函数将在网络扩展中实际实现
class FFIWrapper {
    private let networkManager: NetworkExtensionManager
    private let logger = Logger(subsystem: "site.yinmo.terracotta", category: "FFIWrapper")
    
    init(networkManager: NetworkExtensionManager) {
        self.networkManager = networkManager
    }
    
    // 通过网络扩展调用create_room
    func createRoom(roomName: String, completion: @escaping (Result<String, Error>) -> Void) {
        logger.info("Creating room with name: \(roomName)")
        
        let message = "CREATE_ROOM:\(roomName)"
        networkManager.sendMessage(message) { response in
            DispatchQueue.main.async {
                if let response = response, let responseString = String(data: response, encoding: .utf8) {
                    if responseString.hasPrefix("ERROR:") {
                        let errorMessage = String(responseString.dropFirst(6)) // Remove "ERROR:" prefix
                        let error = TerracottaError.ffiError(errorMessage)
                        self.logger.error("Failed to create room: \(errorMessage)")
                        completion(.failure(error))
                    } else {
                        self.logger.info("Successfully created room: \(responseString)")
                        completion(.success(responseString))
                    }
                } else {
                    let error = TerracottaError.ffiError("No response from network extension")
                    self.logger.error("No response when creating room")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 通过网络扩展调用join_room
    func joinRoom(roomCode: String, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.info("Joining room with code: \(roomCode)")
        
        let message = "JOIN_ROOM:\(roomCode)"
        networkManager.sendMessage(message) { response in
            DispatchQueue.main.async {
                if let response = response, let responseString = String(data: response, encoding: .utf8) {
                    if responseString.hasPrefix("ERROR:") {
                        let errorMessage = String(responseString.dropFirst(6)) // Remove "ERROR:" prefix
                        let error = TerracottaError.ffiError(errorMessage)
                        self.logger.error("Failed to join room: \(errorMessage)")
                        completion(.failure(error))
                    } else {
                        self.logger.info("Successfully joined room: \(roomCode)")
                        completion(.success(()))
                    }
                } else {
                    let error = TerracottaError.ffiError("No response from network extension")
                    self.logger.error("No response when joining room")
                    completion(.failure(error))
                }
            }
        }
    }
}