@preconcurrency import NetworkExtension
import os

// Terracotta-iOS
// 
// Copyright (C) 2026 herbrine8403
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
// 
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

public struct RoomInfo: Codable, Identifiable {
    public var id: String {
        return code
    }
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

// 本地化支持扩展
public extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localizedFormat(_ arguments: CVarArg...) -> String {
        return String(format: localized, arguments: arguments)
    }
}
