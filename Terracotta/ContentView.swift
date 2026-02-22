import SwiftUI
import TerracottaShared

struct ContentView: View {
    @EnvironmentObject var networkManager: NetworkExtensionManager
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var logTailer: LogTailer
    
    @State private var roomCode: String = ""
    @State private var roomName: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 应用标题
                Text("陶瓦联机")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // VPN状态显示
                HStack {
                    Text("状态:")
                    statusIndicator
                    Text(statusText)
                }
                
                // 连接/断开按钮
                if networkManager.status == .disconnected {
                    Button(action: connectToRoom) {
                        Text("连接")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: disconnectFromRoom) {
                        Text("断开连接")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                
                // 创建房间部分
                GroupBox(label: Text("创建房间")) {
                    VStack {
                        TextField("房间名称", text: $roomName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: createRoom) {
                            Text("创建房间")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .disabled(roomManager.isCreatingRoom)
                    }
                }
                
                // 加入房间部分
                GroupBox(label: Text("加入房间")) {
                    VStack {
                        TextField("房间代码", text: $roomCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: joinRoom) {
                            Text("加入房间")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        .disabled(roomManager.isJoiningRoom)
                    }
                }
                
                Spacer()
            }
            .padding()
            .alert("错误", isPresented: $showingAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }
    
    private var statusText: String {
        switch networkManager.status {
        case .disconnected:
            return "已断开"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .error:
            return "错误"
        }
    }
    
    private var statusColor: Color {
        switch networkManager.status {
        case .disconnected:
            return .red
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    private func connectToRoom() {
        // 连接逻辑
    }
    
    private func disconnectFromRoom() {
        networkManager.stopVPN()
    }
    
    private func createRoom() {
        roomManager.createRoom(name: roomName) { result in
            switch result {
            case .success(let roomCode):
                DispatchQueue.main.async {
                    alertMessage = "房间创建成功: \(roomCode)"
                    showingAlert = true
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    alertMessage = "创建房间错误: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func joinRoom() {
        if roomCode.isEmpty {
            alertMessage = "请输入房间代码"
            showingAlert = true
            return
        }
        
        roomManager.joinRoom(code: roomCode) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    alertMessage = "成功加入房间"
                    showingAlert = true
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    alertMessage = "加入房间错误: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NetworkExtensionManager())
            .environmentObject(RoomManager(networkManager: NetworkExtensionManager()))
            .environmentObject(LogTailer())
    }
}