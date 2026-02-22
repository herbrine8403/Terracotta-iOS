import Foundation
import NetworkExtension
import TerracottaShared

/// 与原版陶瓦联机兼容的网络配置管理器
class NetworkConfigManager {
    
    /// 生成与其他端兼容的网络配置
    static func generateCompatibleConfig(for roomInfo: RoomInfo, isHost: Bool = false) -> String {
        // 从房间代码中提取信息
        let cleanCode = roomInfo.code
            .replacingOccurrences(of: "U/", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        // 使用房间代码的一部分作为网络密钥，确保与其他端一致
        let networkSecret = generateNetworkSecret(from: cleanCode)
        let networkName = generateNetworkName(from: roomInfo.name, code: cleanCode)
        
        // 根据是否是房主设置不同的配置
        var config = """
        [flags]
        no_tun = false
        dhcp = true
        """
        
        if isHost {
            config += """
            
        [scaffolding]
        enable = true
        port = 13448
        """
        }
        
        config += """
        
        [network_identity]
        network_name = "\(networkName)"
        network_secret = "\(networkSecret)"
        
        [listeners]
        - "udp://0.0.0.0:11010"
        - "tcp://0.0.0.0:11010"
        
        [dhcp]
        ipv4 = "10.14.0.0/16"
        
        [rpc]
        listen_port = 13448
        
        [virtual_dns]
        enable = true
        """
        
        return config
    }
    
    /// 从房间代码生成网络密钥
    private static func generateNetworkSecret(from code: String) -> String {
        // 使用与原版陶瓦联机相同的算法生成网络密钥
        // 确保不同平台生成相同的密钥
        let paddedCode = code.padding(toLength: 32, withPad: "0", startingAt: 0)
        return String(paddedCode[..<paddedCode.index(paddedCode.startIndex, offsetBy: min(32, paddedCode.count))]).lowercased()
    }
    
    /// 生成网络名称
    private static func generateNetworkName(from baseName: String, code: String) -> String {
        // 确保网络名称与其他平台一致
        return baseName.isEmpty ? "Terracotta-\(String(code.prefix(8)))" : baseName
    }
    
    /// 生成用于Minecraft局域网发现的配置
    static func generateMinecraftConfig() -> String {
        return """
        [minecraft]
        enable_lan_discovery = true
        lan_port = 25565
        """
    }
}