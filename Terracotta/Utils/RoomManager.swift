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
        
        // 创建房间，生成与其他端兼容的配置
        let roomCode = generateRoomCode(for: name)
        let config = NetworkConfigManager.generateCompatibleConfig(for: RoomInfo(code: roomCode, name: name), isHost: true)
        
        // 保存配置以便网络扩展使用
        if let defaults = UserDefaults(suiteName: APP_GROUP_ID) {
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
            
            do {
                let data = try JSONEncoder().encode(options)
                defaults.set(data, forKey: "VPNConfig")
                defaults.synchronize()
            } catch {
                logger.error("Failed to save VPN config: \(error.localizedDescription)")
            }
        }
        
        // 在主线程上完成操作
        DispatchQueue.main.async {
            defer {
                self.isCreatingRoom = false
            }
            
            // 创建房间信息
            let roomInfo = RoomInfo(code: roomCode, name: name)
            self.currentRoom = roomInfo
            self.rooms.append(roomInfo)
            
            self.logger.info("Successfully created room: \(roomCode)")
            completion(.success(roomCode))
        }
    }
    
    func joinRoom(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.info("Joining room with code: \(code)")
        isJoiningRoom = true
        errorMessage = nil
        
        // 直接处理房间加入逻辑，不需要ffi调用
        // 解析房间代码获取网络配置信息
        if let roomInfo = parseRoomCode(code) {
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
            
            // 保存配置
            if let defaults = UserDefaults(suiteName: APP_GROUP_ID) {
                do {
                    let data = try JSONEncoder().encode(options)
                    defaults.set(data, forKey: "VPNConfig")
                    defaults.synchronize()
                } catch {
                    logger.error("Failed to save VPN config: \(error.localizedDescription)")
                }
            }
            
            // 在主线程上完成操作
            DispatchQueue.main.async {
                defer {
                    self.isJoiningRoom = false
                }
                
                self.currentRoom = roomInfo
                self.networkManager.startVPN(options: options)
                completion(.success(()))
            }
        } else {
            let errorStr = "Invalid room code format"
            self.errorMessage = errorStr
            self.logger.error("Failed to parse room code: \(errorStr)")
            
            DispatchQueue.main.async {
                self.isJoiningRoom = false
                completion(.failure(NSError(domain: "RoomManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: errorStr])))
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
    
    private func generateRoomCode(for name: String) -> String {
        // 使用兼容的房间代码生成器
        return CompatibilityChecker.generateConsistentRoomCode()
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