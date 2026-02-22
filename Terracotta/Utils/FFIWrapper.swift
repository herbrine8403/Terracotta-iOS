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
    
    // 通过网络扩展调用create_room - 这个方法现在不再需要，因为使用了兼容性检查器
    // 我们保留此方法以备不时之需
    func createRoom(roomName: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 创建房间代码
        let roomCode = CompatibilityChecker.generateConsistentRoomCode()
        completion(.success(roomCode))
    }
    
    // 通过网络扩展调用join_room - 这个方法现在不再需要，因为RoomManager直接处理
    func joinRoom(roomCode: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 验证房间代码格式
        if roomCode.hasPrefix("U/") && roomCode.count >= 15 {
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "FFIWrapper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid room code format"])))
        }
    }
}