import Foundation
import NetworkExtension
import os
import TerracottaShared

class RoomManager: ObservableObject {
    @Published var currentRoom: RoomInfo?
    @Published var isCreatingRoom = false
    @Published var isJoiningRoom = false
    @Published var errorMessage: String?
    
    private let networkManager: NetworkExtensionManager
    private let ffiWrapper: FFIWrapper
    private let logger = Logger(subsystem: "site.yinmo.terracotta", category: "RoomManager")
    
    init(networkManager: NetworkExtensionManager) {
        self.networkManager = networkManager
        self.ffiWrapper = FFIWrapper(networkManager: networkManager)
    }
    
    func createRoom(name: String, completion: @escaping (Result<String, Error>) -> Void) {
        logger.info("Creating room with name: \(name)")
        isCreatingRoom = true
        errorMessage = nil
        
        ffiWrapper.createRoom(roomName: name) { result in
            DispatchQueue.main.async {
                defer {
                    self.isCreatingRoom = false
                }
                
                switch result {
                case .success(let roomCode):
                    // 创建房间信息
                    let roomInfo = RoomInfo(code: roomCode, name: name)
                    self.currentRoom = roomInfo
                    
                    self.logger.info("Successfully created room: \(roomCode)")
                    completion(.success(roomCode))
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.logger.error("Failed to create room: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func joinRoom(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.info("Joining room with code: \(code)")
        isJoiningRoom = true
        errorMessage = nil
        
        ffiWrapper.joinRoom(roomCode: code) { result in
            DispatchQueue.main.async {
                defer {
                    self.isJoiningRoom = false
                }
                
                switch result {
                case .success:
                    // 解析房间代码获取网络配置信息
                    if let roomInfo = self.parseRoomCode(code) {
                        self.currentRoom = roomInfo
                        
                        // 启动VPN连接
                        let options = TerracottaOptions(
                            config: self.generateConfigForRoom(roomInfo),
                            ipv4: nil,
                            ipv6: nil,
                            mtu: nil,
                            routes: [],
                            logLevel: .info,
                            magicDNS: false,
                            dns: []
                        )
                        
                        self.networkManager.startVPN(options: options)
                        completion(.success(()))
                    } else {
                        let errorStr = "Invalid room code format"
                        self.errorMessage = errorStr
                        self.logger.error("Failed to parse room code: \(errorStr)")
                        completion(.failure(NSError(domain: "RoomManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: errorStr])))
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.logger.error("Failed to join room: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func parseRoomCode(_ code: String) -> RoomInfo? {
        // 简单的房间代码解析逻辑，实际实现可能需要更复杂的解析
        // 假设格式为 U/XXXX-XXXX-XXXX-XXXX
        let components = code.split(separator: "/")
        if components.count >= 2 && components[0] == "U" {
            let roomName = "Room-\(String(components[1]).prefix(4))"
            return RoomInfo(code: code, name: roomName)
        }
        return nil
    }
    
    private func generateConfigForRoom(_ roomInfo: RoomInfo) -> String {
        // 生成TOML格式的配置
        // 这里使用简化的配置，实际实现可能需要更复杂的配置生成逻辑
        
        let config = """
        [flags]
        no_tun = false
        dhcp = true
        
        [network_identity]
        network_name = "\(roomInfo.name)"
        network_secret = "terracotta-\(roomInfo.code)"
        
        [listeners]
        - "udp://0.0.0.0:11010"
        
        [dhcp]
        ipv4 = "10.14.0.0/16"
        """
        
        return config
    }
    
    func leaveRoom() {
        logger.info("Leaving room")
        currentRoom = nil
        networkManager.stopVPN()
    }
}