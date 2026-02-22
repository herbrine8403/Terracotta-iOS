import SwiftUI
import TerracottaShared

@available(iOS 15.4, *)
struct ContentView: View {
    @EnvironmentObject var networkManager: NetworkExtensionManager
    @EnvironmentObject var roomManager: RoomManager
    @EnvironmentObject var logTailer: LogTailer
    
    @State private var roomCode: String = ""
    @State private var roomName: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingCreateSheet = false
    @State private var showingJoinSheet = false
    
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
                        Button(action: {
                            showingCreateSheet = true
                        }) {
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
                        Button(action: {
                            showingJoinSheet = true
                        }) {
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
                
                // 当前房间信息
                if let currentRoom = roomManager.currentRoom {
                    GroupBox(label: Text("当前房间")) {
                        VStack(alignment: .leading) {
                            Text("房间代码: \(currentRoom.code)")
                                .font(.caption)
                            Text("房间名称: \(currentRoom.name)")
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            // 修复iOS 14.5兼容性问题 - 现在应该是15.4
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateRoomView(
                    roomName: $roomName,
                    isPresented: $showingCreateSheet
                ) { result in
                    switch result {
                    case .success(let roomCode):
                        alertMessage = "房间创建成功: \(roomCode)"
                        showingAlert = true
                    case .failure(let error):
                        alertMessage = "创建房间错误: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
            .sheet(isPresented: $showingJoinSheet) {
                JoinRoomView(
                    roomCode: $roomCode,
                    isPresented: $showingJoinSheet
                ) { result in
                    switch result {
                    case .success:
                        alertMessage = "成功加入房间"
                        showingAlert = true
                    case .failure(let error):
                        alertMessage = "加入房间错误: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
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
        // 连接逻辑 - 通过创建或加入房间触发
    }
    
    private func disconnectFromRoom() {
        roomManager.leaveRoom()
    }
}

// 创建房间视图
struct CreateRoomView: View {
    @Binding var roomName: String
    @Binding var isPresented: Bool
    let completion: (Result<String, Error>) -> Void
    
    @State private var tempRoomName: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("创建房间")
                    .font(.title)
                    .fontWeight(.bold)
                
                TextField("房间名称", text: $tempRoomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: createRoom) {
                    Text("创建")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func createRoom() {
        if tempRoomName.isEmpty {
            errorMessage = "请输入房间名称"
            showingError = true
            return
        }
        
        // 通过RoomManager创建房间
        (UIApplication.shared.windows.first?.rootViewController as? UIHostingController<ContentView>)?.rootView
            .roomManager?.createRoom(name: tempRoomName) { result in
                switch result {
                case .success(let roomCode):
                    DispatchQueue.main.async {
                        self.roomName = self.tempRoomName
                        self.isPresented = false
                        self.completion(.success(roomCode))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.showingError = true
                    }
                }
            }
    }
}

// 加入房间视图
struct JoinRoomView: View {
    @Binding var roomCode: String
    @Binding var isPresented: Bool
    let completion: (Result<Void, Error>) -> Void
    
    @State private var tempRoomCode: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("加入房间")
                    .font(.title)
                    .fontWeight(.bold)
                
                TextField("房间代码", text: $tempRoomCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: joinRoom) {
                    Text("加入")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func joinRoom() {
        if tempRoomCode.isEmpty {
            errorMessage = "请输入房间代码"
            showingError = true
            return
        }
        
        // 通过RoomManager加入房间
        (UIApplication.shared.windows.first?.rootViewController as? UIHostingController<ContentView>)?.rootView
            .roomManager?.joinRoom(code: tempRoomCode) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.roomCode = self.tempRoomCode
                        self.isPresented = false
                        self.completion(.success(()))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.showingError = true
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