import Foundation
import os

// 自定义错误类型
enum TerracottaError: Error, LocalizedError {
    case configurationError(String)
    case networkError(String)
    case vpnError(String)
    case roomError(String)
    case ffiError(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "Configuration Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .vpnError(let message):
            return "VPN Error: \(message)"
        case .roomError(let message):
            return "Room Error: \(message)"
        case .ffiError(let message):
            return "FFI Error: \(message)"
        }
    }
}

// 统一日志管理器
class ErrorLogger {
    static let shared = ErrorLogger()
    private let logger = Logger(subsystem: "site.yinmo.terracotta", category: "ErrorLogger")
    
    private init() {}
    
    func logError(_ error: Error, function: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.error("❌ [\(fileName):\(line)] \(function) - \(error.localizedDescription)")
    }
    
    func logInfo(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.info("ℹ️ [\(fileName):\(line)] \(function) - \(message)")
    }
    
    func logWarning(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.warning("⚠️ [\(fileName):\(line)] \(function) - \(message)")
    }
    
    func logCritical(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.critical("🚨 [\(fileName):\(line)] \(function) - \(message)")
    }
}

// 错误处理扩展
extension Result {
    func logErrorIfNeeded(function: String = #function, file: String = #file, line: Int = #line) {
        switch self {
        case .failure(let error):
            ErrorLogger.shared.logError(error, function: function, file: file, line: line)
        case .success:
            break
        }
    }
}