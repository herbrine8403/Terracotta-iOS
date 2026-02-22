import Foundation
import NetworkExtension
import os
import TerracottaShared

class RoomManager: ObservableObject {
    @Published var currentRoom: RoomInfo?
    @Published var isCreatingRoom = false
    @Published var isJoiningRoom = false
    @Published var errorMessage: String?
    @Published var rooms: [RoomInfo] = []
    
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
                    self.rooms.append(roomInfo)
                    
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
                        
                        // 使用兼容的配置生成器
                        let config = NetworkConfigManager.generateCompatibleConfig(for: roomInfo, isHost: false)
                        
                        let options = TerracottaOptions(
                            config: config,
                            ipv4: nil,
                            ipv6: nil,
                            mtu: 1380,
                            routes: [],
                            logLevel: .info,
                            magicDNS: true,
                            dns: ["1.1.1.1", "8.8.8.8"]
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
        // 验证房间代码格式，应该为 U/XXXX-XXXX-XXXX-XXXX
        let components = code.split(separator: "/")
        if components.count < 2 || components[0] != "U" {
            return nil
        }
        
        // 提取各个部分
        let parts = String(components[1]).split(separator: "-")
        if parts.count != 4 {
            return nil
        }
        
        // 从第一部分获取房间名称
        let roomName = "Room-\(String(parts[0]))"
        return RoomInfo(code: code, name: roomName)
    }
    
    private func generateConfigForRoom(_ roomInfo: RoomInfo) -> String {
        // 生成与其他端兼容的TOML格式配置
        // 解析房间代码以提取网络信息
        let codeWithoutPrefix = roomInfo.code
            .replacingOccurrences(of: "U/", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        // 使用房间代码的一部分作为网络密钥
        let networkSecret = codeWithoutPrefix.count > 16 ? 
            String(codeWithoutPrefix.prefix(16)) : codeWithoutPrefix
        
        let config = """
        [flags]
        no_tun = false
        dhcp = true
        
        [network_identity]
        network_name = "\(roomInfo.name)"
        network_secret = "\(networkSecret.lowercased())"
        
        [listeners]
        - "udp://0.0.0.0:11010"
        - "tcp://0.0.0.0:11010"
        
        [dhcp]
        ipv4 = "10.14.0.0/16"
        
        [rpc]
        listen_port = 13448
        
        [websocket]
        enable = false
        """
        
        return config
    }
    
    func leaveRoom() {
        logger.info("Leaving room")
        currentRoom = nil
        networkManager.stopVPN()
    }
    
    func listRooms() -> [RoomInfo] {
        return rooms
    }
    
    func refreshRooms() {
        // 实现房间列表刷新逻辑
        logger.info("Refreshing room list")
        // 这里可以实现扫描或从服务器获取房间列表的逻辑
    }
}