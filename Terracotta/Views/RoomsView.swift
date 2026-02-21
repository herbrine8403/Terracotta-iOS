import SwiftUI
import TerracottaShared
import UIKit

struct RoomsView: View {
    @EnvironmentObject private var networkManager: NetworkExtensionManager
    @EnvironmentObject private var profileStore: ProfileStore
    
    @State private var showingCreateRoomSheet = false
    @State private var showingJoinRoomSheet = false
    @State private var rooms: [RoomInfo] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rooms")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                Button(action: {
                    showingCreateRoomSheet.toggle()
                }) {
                    Text("Create Room")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingJoinRoomSheet.toggle()
                }) {
                    Text("Join Room")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                }
            }
            
            if rooms.isEmpty {
                Text("No rooms available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                List(rooms) { room in
                    RoomCard(room: room)
                }
                .listStyle(PlainListStyle())
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingCreateRoomSheet) {
            CreateRoomSheet(rooms: $rooms)
        }
        .sheet(isPresented: $showingJoinRoomSheet) {
            JoinRoomSheet()
        }
    }
}

struct RoomCard: View {
    let room: RoomInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(room.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(room.players.count) players")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text("Code: \(room.code)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Created: \(formatDate(room.created))")
                .font(.caption)
                .foregroundColor(.gray)
            
            if !room.players.isEmpty {
                Text("Players:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(room.players, id: \.name) {
                    player in
                    Text("- \(player.name) (\(player.ip))")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CreateRoomSheet: View {
    @Binding var rooms: [RoomInfo]
    @EnvironmentObject private var networkManager: NetworkExtensionManager
    
    @State private var roomName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdRoomCode: String?
    @State private var isPresented = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Room")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                TextField("Room Name", text: $roomName)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                if let createdRoomCode = createdRoomCode {
                    VStack {
                        Text("Room Created!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("Room Code:")
                            .font(.subheadline)
                        
                        Text(createdRoomCode)
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        Button(action: {
                            // 复制房间代码到剪贴板
                            UIPasteboard.general.string = createdRoomCode
                        }) {
                            Text("Copy Code")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Create Room", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    // 关闭 sheet
                },
                trailing: Button(action: {
                    createRoom()
                }) {
                    Text("Create")
                        .fontWeight(.semibold)
                }
                .disabled(roomName.isEmpty || isCreating)
            )
        }
    }
    
    private func createRoom() {
        isCreating = true
        errorMessage = nil
        
        // 暂时注释掉 FFI 函数调用，需要实现
        /*
        var errMsg: UnsafePointer<CChar>? = nil
        var result: UnsafePointer<CChar>? = nil
        
        let status = create_room(roomName, &errMsg, &result)
        
        if status == 0, let result = result {
            let roomCode = String(cString: result)
            createdRoomCode = roomCode
            
            // 添加到房间列表
            let newRoom = RoomInfo(code: roomCode, name: roomName)
            rooms.append(newRoom)
        } else if let errMsg = errMsg {
            errorMessage = String(cString: errMsg)
        } else {
            errorMessage = "Failed to create room"
        }
        */
        
        // 临时实现，生成一个随机房间代码
        let roomCode = "\(Int.random(in: 1000...9999))"
        createdRoomCode = roomCode
        
        // 添加到房间列表
        let newRoom = RoomInfo(code: roomCode, name: roomName)
        rooms.append(newRoom)
        
        isCreating = false
    }
}

struct JoinRoomSheet: View {
    @EnvironmentObject private var networkManager: NetworkExtensionManager
    
    @State private var roomCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Join Room")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                TextField("Room Code", text: $roomCode)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                if joinSuccess {
                    Text("Joined successfully!")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Join Room", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    // 关闭 sheet
                },
                trailing: Button(action: {
                    joinRoom()
                }) {
                    Text("Join")
                        .fontWeight(.semibold)
                }
                .disabled(roomCode.isEmpty || isJoining)
            )
        }
    }
    
    private func joinRoom() {
        isJoining = true
        errorMessage = nil
        
        // 暂时注释掉 FFI 函数调用，需要实现
        /*
        var errMsg: UnsafePointer<CChar>? = nil
        
        let status = join_room(roomCode, &errMsg)
        
        if status == 0 {
            joinSuccess = true
            // 启动 VPN 连接
            networkManager.startVPN()
        } else if let errMsg = errMsg {
            errorMessage = String(cString: errMsg)
        } else {
            errorMessage = "Failed to join room"
        }
        */
        
        // 临时实现
        joinSuccess = true
        // 启动 VPN 连接
        networkManager.startVPN()
        
        isJoining = false
    }
}

struct RoomsView_Previews: PreviewProvider {
    static var previews: some View {
        RoomsView()
            .environmentObject(NetworkExtensionManager())
            .environmentObject(ProfileStore())
    }
}
