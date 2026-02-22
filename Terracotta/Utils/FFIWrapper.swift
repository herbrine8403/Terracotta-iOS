import Foundation
import NetworkExtension
import os
import TerracottaShared

// 通过NetworkExtensionManager访问Rust FFI函数
// 这些函数将在网络扩展中实际实现
class FFIWrapper {
    private let networkManager: NetworkExtensionManager
    
    init(networkManager: NetworkExtensionManager) {
        self.networkManager = networkManager
    }
    
    // 通过网络扩展调用create_room
    func createRoom(roomName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let message = "CREATE_ROOM:\(roomName)"
        networkManager.sendMessage(message) { response in
            if let response = response, let responseString = String(data: response, encoding: .utf8) {
                if responseString.hasPrefix("ERROR:") {
                    let errorMessage = String(responseString.dropFirst(6)) // Remove "ERROR:" prefix
                    completion(.failure(NSError(domain: "FFIWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    completion(.success(responseString))
                }
            } else {
                completion(.failure(NSError(domain: "FFIWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response from network extension"])))
            }
        }
    }
    
    // 通过网络扩展调用join_room
    func joinRoom(roomCode: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let message = "JOIN_ROOM:\(roomCode)"
        networkManager.sendMessage(message) { response in
            if let response = response, let responseString = String(data: response, encoding: .utf8) {
                if responseString.hasPrefix("ERROR:") {
                    let errorMessage = String(responseString.dropFirst(6)) // Remove "ERROR:" prefix
                    completion(.failure(NSError(domain: "FFIWrapper", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    completion(.success(()))
                }
            } else {
                completion(.failure(NSError(domain: "FFIWrapper", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response from network extension"])))
            }
        }
    }
}