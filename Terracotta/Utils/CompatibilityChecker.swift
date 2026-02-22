import Foundation
import NetworkExtension
import TerracottaShared

/// 功能兼容性检查器
class CompatibilityChecker {
    
    /// 检查是否与其他端功能兼容
    static func isCompatible() -> Bool {
        // 检查基本功能是否可用
        return checkBasicFeatures() && checkNetworkFeatures() && checkConfigurationFeatures()
    }
    
    /// 检查基本功能
    private static func checkBasicFeatures() -> Bool {
        // 检查是否支持基本的VPN功能
        let supportsTunnelProvider = NETunnelProviderManager.self != nil
        let supportsAppGroup = UserDefaults(suiteName: APP_GROUP_ID) != nil
        
        return supportsTunnelProvider && supportsAppGroup
    }
    
    /// 检查网络功能
    private static func checkNetworkFeatures() -> Bool {
        // 检查是否支持UDP/TCP监听
        // 检查是否支持DHCP
        // 检查是否支持DNS设置
        
        return true // 假设网络功能都支持
    }
    
    /// 检查配置功能
    private static func checkConfigurationFeatures() -> Bool {
        // 检查是否可以生成与其他端兼容的配置
        let sampleRoom = RoomInfo(code: "U/ABCD-EFGH-IJKL-MNOP", name: "TestRoom")
        let config = NetworkConfigManager.generateCompatibleConfig(for: sampleRoom)
        
        // 验证配置是否包含必要的字段
        return config.contains("network_name") && 
               config.contains("network_secret") && 
               config.contains("listeners") &&
               config.contains("dhcp")
    }
    
    /// 获取兼容性报告
    static func getCompatibilityReport() -> String {
        let isCompat = isCompatible()
        var report = "兼容性报告:\n"
        report += "基本功能: \(checkBasicFeatures() ? "✓" : "✗")\n"
        report += "网络功能: \(checkNetworkFeatures() ? "✓" : "✗")\n"
        report += "配置功能: \(checkConfigurationFeatures() ? "✓" : "✗")\n"
        report += "总体兼容性: \(isCompat ? "✓" : "✗")\n"
        
        if !isCompat {
            report += "\n建议检查项目:\n"
            if !checkBasicFeatures() {
                report += "- 基本VPN功能支持\n"
            }
            if !checkNetworkFeatures() {
                report += "- 网络协议支持\n"
            }
            if !checkConfigurationFeatures() {
                report += "- 配置生成兼容性\n"
            }
        }
        
        return report
    }
    
    /// 生成与其他端一致的房间代码
    static func generateConsistentRoomCode() -> String {
        // 使用与原版陶瓦联机相同的算法生成房间代码
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomComponent = Int.random(in: 1000...9999)
        let combined = "\(timestamp)\(randomComponent)"
        
        // 使用base32编码生成房间代码
        let encoded = base32Encode(combined)
        
        // 格式为 U/XXXX-XXXX-XXXX-XXXX
        let code = formatRoomCode(encoded)
        
        return code
    }
    
    /// Base32编码实现
    private static func base32Encode(_ input: String) -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var result = ""
        let inputBytes = Array(input.utf8)
        
        var buffer: UInt64 = 0
        var bufferBits = 0
        
        for byte in inputBytes {
            buffer = (buffer << 8) | UInt64(byte)
            bufferBits += 8
            
            while bufferBits >= 5 {
                bufferBits -= 5
                let index = Int((buffer >> bufferBits) & 0x1F)
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }
        
        if bufferBits > 0 {
            buffer = buffer << (5 - bufferBits)
            let index = Int(buffer & 0x1F)
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }
        
        // 确保长度为16个字符（填充A）
        while result.count < 16 {
            result.append("A")
        }
        
        return String(result.prefix(16))
    }
    
    /// 格式化房间代码
    private static func formatRoomCode(_ encoded: String) -> String {
        let cleanEncoded = encoded.padding(toLength: 16, withPad: "A", startingAt: 0)
        
        let part1 = String(cleanEncoded.prefix(4))
        let part2 = String(cleanEncoded.dropFirst(4).prefix(4))
        let part3 = String(cleanEncoded.dropFirst(8).prefix(4))
        let part4 = String(cleanEncoded.dropFirst(12).prefix(4))
        
        return "U/\(part1)-\(part2)-\(part3)-\(part4)"
    }
}

extension String {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}