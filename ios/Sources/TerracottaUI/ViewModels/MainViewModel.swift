//
//  MainViewModel.swift
//  TerracottaUI
//
//  View model for main interface
//

import SwiftUI
import Combine
import TerracottaCore

public class MainViewModel: ObservableObject {
    @Published var showingGuestInput = false
    @Published var inviteCodeInput = ""
    @Published var playerNameInput = ""
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var alertTitle = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let terracottaCore = TerracottaCore.shared
    private let vpnManager = VPNManager()
    
    public init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    public func onViewAppear() {
        // Initialize player name with device name or default
        if playerNameInput.isEmpty {
            playerNameInput = UIDevice.current.name.prefix(16).description
        }
    }
    
    public func startHosting() {
        Task {
            await terracottaCore.setScanningState(playerName: playerNameInput)
        }
    }
    
    public func startJoining() {
        showingGuestInput = true
    }
    
    public func joinRoom() {
        guard !inviteCodeInput.isEmpty else {
            showAlert(title: "输入错误", message: "请输入邀请码")
            return
        }
        
        guard !playerNameInput.isEmpty else {
            showAlert(title: "输入错误", message: "请输入玩家名称")
            return
        }
        
        Task {
            do {
                await terracottaCore.setScanningState(roomCode: inviteCodeInput, playerName: playerNameInput)
                try await terracottaCore.joinRoom(roomCode: inviteCodeInput, playerName: playerNameInput)
            } catch {
                showAlert(title: "加入房间失败", message: error.localizedDescription)
            }
        }
        
        showingGuestInput = false
    }
    
    public func cancelOperation() {
        Task {
            await terracottaCore.leaveRoom()
            await terracottaCore.setWaitingState()
        }
    }
    
    public func closeRoom() {
        cancelOperation()
    }
    
    public func leaveRoom() {
        cancelOperation()
    }
    
    public func retryOperation() {
        // Retry logic based on current state
        switch terracottaCore.currentState {
        case .hostScanning:
            startHosting()
        case .guestConnecting, .guestStarting:
            if !inviteCodeInput.isEmpty {
                joinRoom()
            } else {
                startJoining()
            }
        default:
            break
        }
    }
    
    public func backToMain() {
        cancelOperation()
    }
    
    public func openCommunitySupport() {
        guard let url = URL(string: "https://docs.hmcl.net/groups.html") else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor state changes for automatic actions
        terracottaCore.$currentState
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
        
        // Monitor errors
        terracottaCore.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] errorMessage in
                self?.showAlert(title: "错误", message: errorMessage)
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: TerracottaState) {
        switch state {
        case .hostStarting:
            Task {
                do {
                    // Start ZeroTier node if not already started
                    if terracottaCore.nodeInfo == nil {
                        try await terracottaCore.startNode(nodeId: generateNodeId())
                    }
                    
                    // Join default network
                    try await terracottaCore.joinNetwork(networkId: "default_network_id")
                    
                    // Create room
                    let roomCode = try await terracottaCore.createRoom(playerName: playerNameInput)
                    
                    // Update room info
                    await MainActor.run {
                        self.terracottaCore.roomInfo = RoomInfo(roomCode: roomCode, isHost: true)
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "创建房间失败", message: error.localizedDescription)
                    }
                }
            }
            
        case .guestConnecting:
            Task {
                do {
                    // Start ZeroTier node if not already started
                    if terracottaCore.nodeInfo == nil {
                        try await terracottaCore.startNode(nodeId: generateNodeId())
                    }
                    
                    // Join default network
                    try await terracottaCore.joinNetwork(networkId: "default_network_id")
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "连接失败", message: error.localizedDescription)
                    }
                }
            }
            
        default:
            break
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    private func generateNodeId() -> String {
        // Generate a random node ID for ZeroTier
        return String(format: "%010llx", UInt64.random(in: 1...UInt64.max))
    }
}

// MARK: - Guest Input View

extension MainViewModel {
    public var guestInputView: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Text("加入房间")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邀请码")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("请输入邀请码", text: $inviteCodeInput)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("玩家名称")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("请输入玩家名称", text: $playerNameInput)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("加入房间") {
                        joinRoom()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .blue))
                    .disabled(inviteCodeInput.isEmpty || playerNameInput.isEmpty)
                    
                    Button("取消") {
                        showingGuestInput = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarHidden(true)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}