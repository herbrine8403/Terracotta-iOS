import Foundation
import NetworkExtension
import os
import TerracottaShared

/// 与原版陶瓦联机兼容的网络扩展配置管理器
class ExtensionConfigManager {
    
    private static let logger = Logger(subsystem: "site.yinmo.terracotta", category: "ExtensionConfigManager")
    
    /// 从TOML配置字符串中提取网络设置
    static func extractNetworkSettings(from config: String) -> NEPacketTunnelNetworkSettings? {
        // 解析TOML配置以提取网络设置
        // 由于Swift没有内置的TOML解析器，我们使用简单的正则表达式方法
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // 设置默认值
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings
        
        // IPv6 设置 (可选)
        let ipv6Settings = NEIPv6Settings(addresses: ["fd42:4242:4242::2"], networkPrefixLength: 64)
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings
        
        // DNS 设置
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dnsSettings
        
        // MTU 设置 - 默认1380，与其他端保持一致
        settings.mtu = 1380
        
        // 尝试从配置中提取特定设置
        if let mtuValue = extractMTU(from: config) {
            settings.mtu = mtuValue
        }
        
        if let ipv4Addresses = extractIPv4Addresses(from: config) {
            settings.ipv4Settings = ipv4Settings // 创建新的实例以覆盖地址
            settings.ipv4Settings?.addresses = ipv4Addresses
        }
        
        if let dnsServers = extractDNSServers(from: config) {
            settings.dnsSettings = NEDNSSettings(servers: dnsServers)
        }
        
        return settings
    }
    
    /// 从配置中提取MTU值
    private static func extractMTU(from config: String) -> NSNumber? {
        // 尝试匹配 config 中的 MTU 设置
        let mtuRegex = try? NSRegularExpression(pattern: "mtu\\s*=\\s*(\\d+)")
        let range = NSRange(location: 0, length: config.utf16.count)
        
        if let match = mtuRegex?.firstMatch(in: config, options: [], range: range) {
            let mtuString = (config as NSString).substring(with: match.range(at: 1))
            if let mtuInt = Int(mtuString) {
                return NSNumber(value: mtuInt)
            }
        }
        
        return nil
    }
    
    /// 从配置中提取IPv4地址
    private static func extractIPv4Addresses(from config: String) -> [String]? {
        // 尝试匹配 DHCP 配置中的 IPv4 网络
        let dhcpRegex = try? NSRegularExpression(pattern: "\\[dhcp\\].*?ipv4\\s*=\\s*[\"\\']([^\"\\']+)['\"]", options: .dotMatchesLineSeparators)
        let range = NSRange(location: 0, length: config.utf16.count)
        
        if let match = dhcpRegex?.firstMatch(in: config, options: [], range: range) {
            let networkString = (config as NSString).substring(with: match.range(at: 1))
            // 假设格式为 "10.14.0.0/16"，我们需要从中提取一个地址
            if networkString.contains("/") {
                let baseAddress = networkString.components(separatedBy: "/")[0]
                // 为客户端分配一个该网络内的地址
                let clientAddress = incrementLastOctet(baseAddress)
                return [clientAddress]
            }
        }
        
        return nil
    }
    
    /// 从配置中提取DNS服务器
    private static func extractDNSServers(from config: String) -> [String]? {
        // 尝试匹配 DNS 配置
        let dnsRegex = try? NSRegularExpression(pattern: "\\[dns\\].*?servers\\s*=\\s*\\[([^\\]]+)\\]", options: .dotMatchesLineSeparators)
        let range = NSRange(location: 0, length: config.utf16.count)
        
        if let match = dnsRegex?.firstMatch(in: config, options: [], range: range) {
            let serversString = (config as NSString).substring(with: match.range(at: 1))
            let servers = serversString
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            if !servers.isEmpty && !servers[0].isEmpty {
                return servers
            }
        }
        
        return nil
    }
    
    /// 递增IP地址的最后一个八位组
    private static func incrementLastOctet(_ ipAddress: String) -> String {
        let components = ipAddress.split(separator: ".").compactMap { Int($0) }
        if components.count == 4 {
            var newComponents = components
            newComponents[3] += 2  // 避开端点地址，使用 +2
            if newComponents[3] > 254 {
                newComponents[3] = 10  // 如果超过范围，使用一个固定的值
            }
            return newComponents.map(String.init).joined(separator: ".")
        }
        return ipAddress
    }
    
    /// 生成默认的兼容配置
    static func generateDefaultConfig(networkName: String, networkSecret: String) -> String {
        return """
        [flags]
        no_tun = false
        dhcp = true
        
        [network_identity]
        network_name = \"\(networkName)\"
        network_secret = \"\(networkSecret)\"
        
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
    }
}