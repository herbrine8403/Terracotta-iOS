import Foundation
import os
import UIKit
import TerracottaShared

class LogTailer: ObservableObject {
    @Published var logLines: [String] = []
    var onLogUpdate: (([String]) -> Void)?
    
    private let logFileURL: URL
    private var fileHandle: FileHandle?
    private var observation: NSObjectProtocol?
    private let maxLines: Int = 1000
    private let logger = Logger(subsystem: "site.yinmo.terracotta", category: "LogTailer")
    
    init() {
        // 使用共享容器中的日志文件位置
        if let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_ID) {
            logFileURL = sharedContainerURL.appendingPathComponent(LOG_FILENAME)
        } else {
            // 回退到文档目录
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            logFileURL = documentsDirectory.appendingPathComponent(LOG_FILENAME)
        }
        
        // 确保日志文件存在
        ensureLogFileExists()
        
        // 添加初始日志
        logToSharedFile("LogTailer initialized at \(Date())")
    }
    
    func start() {
        logger.info("Starting log tailer")
        loadLogs()
        startObserving()
    }
    
    func stop() {
        logger.info("Stopping log tailer")
        stopObserving()
    }
    
    func clearLogs() {
        logger.info("Clearing logs")
        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.logLines.removeAll()
                self.onLogUpdate?([])
            }
        } catch {
            logger.error("Failed to clear log file: \(error.localizedDescription)")
        }
    }
    
    func exportLogs() {
        logger.info("Exporting logs")
        let activityVC = UIActivityViewController(activityItems: [logFileURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true, completion: nil)
        }
    }
    
    private func ensureLogFileExists() {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                try "".write(to: logFileURL, atomically: true, encoding: .utf8)
                logger.info("Created log file at \(self.logFileURL.path)")
            } catch {
                logger.error("Failed to create log file: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadLogs() {
        do {
            let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
            var lines = logContent.components(separatedBy: .newlines)
            
            // 移除空行
            lines = lines.filter { !$0.isEmpty }
            
            // 限制日志行数
            if lines.count > maxLines {
                lines = Array(lines.suffix(maxLines))
            }
            
            DispatchQueue.main.async {
                self.logLines = lines
                self.onLogUpdate?(lines)
            }
        } catch {
            logger.error("Failed to load log file: \(error.localizedDescription)")
        }
    }
    
    private func startObserving() {
        stopObserving()
        
        observation = NotificationCenter.default.addObserver(
            forName: FileHandle.readCompletionNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] (notification) in
            guard let self = self,
                  let data = notification.userInfo?[NSFileHandleNotificationDataItem] as? Data else {
                return
            }
            
            if let string = String(data: data, encoding: .utf8) {
                self.processNewLogData(string)
                
                // 继续监听新数据
                DispatchQueue.global(qos: .background).async {
                    Thread.sleep(forTimeInterval: 0.1) // 避免过快读取
                    DispatchQueue.main.async {
                        self.fileHandle?.readInBackgroundAndNotify()
                    }
                }
            }
        }
        
        do {
            fileHandle = try FileHandle(forReadingFrom: logFileURL)
            fileHandle?.seekToEndOfFile()
            fileHandle?.readInBackgroundAndNotify()
            logger.info("Started observing log file")
        } catch {
            logger.error("Failed to open log file for reading: \(error.localizedDescription)")
        }
    }
    
    private func stopObserving() {
        if let observation = observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
        }
        
        fileHandle?.closeFile()
        fileHandle = nil
        logger.info("Stopped observing log file")
    }
    
    private func processNewLogData(_ data: String) {
        let newLines = data.components(separatedBy: .newlines)
        
        var updatedLines = logLines
        for line in newLines {
            if !line.isEmpty {
                updatedLines.append(line)
            }
        }
        
        // 限制日志行数
        if updatedLines.count > maxLines {
            updatedLines = Array(updatedLines.suffix(maxLines))
        }
        
        DispatchQueue.main.async {
            self.logLines = updatedLines
            self.onLogUpdate?(updatedLines)
        }
    }
    
    // 便捷方法：向共享日志文件写入日志
    func logToSharedFile(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        guard let data = logEntry.data(using: .utf8) else { return }
        
        // 确保文件存在
        ensureLogFileExists()
        
        // 追加到文件
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            // 如果无法打开现有文件，则创建新文件
            do {
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to write to log file: \(error.localizedDescription)")
            }
        }
    }
    
    // 从网络扩展获取日志
    func fetchExtensionLogs(completion: @escaping (Result<String, Error>) -> Void) {
        // 发送消息到网络扩展请求日志
        let networkManager = NetworkExtensionManager()
        networkManager.sendMessage("exportOSLog") { data in
            if let data = data,
               let logs = String(data: data, encoding: .utf8) {
                completion(.success(logs))
            } else {
                completion(.failure(NSError(domain: "LogTailerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch extension logs"])))
            }
        }
    }
}
