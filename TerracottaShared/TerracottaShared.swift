@preconcurrency import NetworkExtension
import os

public let APP_BUNDLE_ID: String = "site.yinmo.terracotta"
public let APP_GROUP_ID: String = "group.site.yinmo.terracotta"
public let ICLOUD_CONTAINER_ID: String = "iCloud.site.yinmo.terracotta"
public let LOG_FILENAME: String = "terracotta.log"

public enum LogLevel: String, Codable, CaseIterable {
    case trace = "trace"
    case debug = "debug"
    case info = "info"
    case warn = "warn"
    case error = "error"
}

public struct TerracottaOptions: Codable {
    public var config: String = ""
    public var ipv4: String?
    public var ipv6: String?
    public var mtu: Int?
    public var routes: [String] = []
    public var logLevel: LogLevel = .info
    public var magicDNS: Bool = false
    public var dns: [String] = []

    public init() {}
}

public struct RoomInfo: Codable {
    public var code: String
    public var name: String
    public var created: Date
    public var players: [PlayerInfo] = []

    public init(code: String, name: String) {
        self.code = code
        self.name = name
        self.created = Date()
    }
}

public struct PlayerInfo: Codable {
    public var name: String
    public var ip: String
    public var joined: Date

    public init(name: String, ip: String) {
        self.name = name
        self.ip = ip
        self.joined = Date()
    }
}

public enum ConnectionStatus: String, Codable, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
}
