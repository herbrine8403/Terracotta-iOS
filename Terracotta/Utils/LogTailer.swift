import Foundation
import os

class LogTailer: ObservableObject {
    @Published var logLines: [String] = []
    var onLogUpdate: (([String]) -> Void)?
    
    private let logFileURL: URL
    private var fileHandle: FileHandle?
    private var observation: NSObjectProtocol?
    private let maxLines: Int = 1000
    
    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = documentsDirectory.appendingPathComponent(LOG_FILENAME)
        
        // 创建日志文件（如果不存在）
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                os_log("Failed to create log file: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
            }
        }
        
        loadLogs()
    }
    
    func start() {
        loadLogs()
        startObserving()
    }
    
    func stop() {
        stopObserving()
    }
    
    func clearLogs() {
        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            logLines.removeAll()
            onLogUpdate?([])
        } catch {
            os_log("Failed to clear log file: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    func exportLogs() {
        let activityVC = UIActivityViewController(activityItems: [logFileURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true, completion: nil)
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
            
            logLines = lines
            onLogUpdate?(lines)
        } catch {
            os_log("Failed to load log file: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    private func startObserving() {
        stopObserving()
        
        observation = NotificationCenter.default.addObserver(
            forName: .NSFileHandleReadCompletion,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] (notification) in
            guard let self = self, let data = notification.userInfo?[NSFileHandleNotificationDataItem] as? Data else {
                return
            }
            
            if let line = String(data: data, encoding: .utf8) {
                self.processNewLogData(line)
                self.fileHandle?.readInBackgroundAndNotify()
            }
        }
        
        do {
            fileHandle = try FileHandle(forReadingFrom: logFileURL)
            fileHandle?.seekToEndOfFile()
            fileHandle?.readInBackgroundAndNotify()
        } catch {
            os_log("Failed to open log file for reading: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    private func stopObserving() {
        if let observation = observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
        }
        
        fileHandle?.closeFile()
        fileHandle = nil
    }
    
    private func processNewLogData(_ data: String) {
        let newLines = data.components(separatedBy: .newlines)
        
        for line in newLines {
            if !line.isEmpty {
                logLines.append(line)
            }
        }
        
        // 限制日志行数
        if logLines.count > maxLines {
            logLines = Array(logLines.suffix(maxLines))
        }
        
        onLogUpdate?(logLines)
    }
}
