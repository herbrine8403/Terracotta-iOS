import SwiftUI

struct LogView: View {
    @EnvironmentObject private var logTailer: LogTailer
    
    @State private var logLines: [String] = []
    @State private var isAutoScrolling = true
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Logs")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack {
                TextField("Search", text: $searchText)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Auto Scroll", isOn: $isAutoScrolling)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredLogLines, id: \.self) {
                        line in
                        Text(line)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(logLevelColor(for: line))
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            
            HStack {
                Button(action: {
                    // 清除日志
                    logTailer.clearLogs()
                    logLines.removeAll()
                }) {
                    Text("Clear")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // 导出日志
                    logTailer.exportLogs()
                }) {
                    Text("Export")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            logLines = logTailer.logLines
            logTailer.onLogUpdate = { newLines in
                logLines = newLines
            }
        }
        .onDisappear {
            logTailer.onLogUpdate = nil
        }
    }
    
    private var filteredLogLines: [String] {
        if searchText.isEmpty {
            return logLines
        } else {
            return logLines.filter { $0.contains(searchText) }
        }
    }
    
    private func logLevelColor(for line: String) -> Color {
        if line.contains("ERROR") {
            return .red
        } else if line.contains("WARN") {
            return .orange
        } else if line.contains("INFO") {
            return .primary
        } else if line.contains("DEBUG") {
            return .blue
        } else if line.contains("TRACE") {
            return .purple
        } else {
            return .secondary
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
            .environmentObject(LogTailer())
    }
}
