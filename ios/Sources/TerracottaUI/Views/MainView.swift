//
//  MainView.swift
//  TerracottaUI
//
//  Main interface for Terracotta iOS app
//

import SwiftUI
import Combine

public struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var terracottaCore = TerracottaCore.shared
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 30) {
                    // Header
                    headerView
                    
                    // Content based on current state
                    contentView
                        .animation(.easeInOut(duration: 0.3), value: terracottaCore.currentState)
                    
                    Spacer()
                    
                    // Footer
                    footerView
                }
                .padding()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onViewAppear()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 10) {
            Text("陶瓦联机")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            
            Text("基于 ZeroTier 的 Minecraft 联机助手")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch terracottaCore.currentState {
        case .waiting:
            RoleSelectionView(
                onHostTapped: viewModel.startHosting,
                onGuestTapped: viewModel.startJoining
            )
            
        case .hostScanning:
            LoadingView(
                title: "正在扫描本地服务器",
                message: "请进入单人存档，按下 ESC 键，选择对局域网开放，点击创建局域网世界。",
                onCancel: viewModel.cancelOperation
            )
            
        case .hostStarting:
            LoadingView(
                title: "正在启动房间",
                message: "请稍候，正在建立网络连接...",
                onCancel: viewModel.cancelOperation
            )
            
        case .hostOk:
            HostResultView(
                roomInfo: terracottaCore.roomInfo,
                onClose: viewModel.closeRoom
            )
            
        case .guestConnecting, .guestStarting:
            LoadingView(
                title: "正在加入房间",
                message: "请稍候，正在连接到房间...",
                onCancel: viewModel.cancelOperation
            )
            
        case .guestOk:
            GuestResultView(
                roomInfo: terracottaCore.roomInfo,
                onLeave: viewModel.leaveRoom
            )
            
        case .exception:
            ErrorView(
                title: "连接错误",
                message: terracottaCore.errorMessage ?? "未知错误",
                onRetry: viewModel.retryOperation,
                onBack: viewModel.backToMain
            )
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Text("版本 \(terracottaCore.getVersion())")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Button("需要帮助？加入社区") {
                viewModel.openCommunitySupport()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.blue)
            .underline()
        }
    }
}

// MARK: - Role Selection View

struct RoleSelectionView: View {
    let onHostTapped: () -> Void
    let onGuestTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            HStack(spacing: 20) {
                // Host tile
                RoleTile(
                    icon: "👑",
                    title: "我想当房主",
                    description: "创建房间并生成邀请码，与好友一起畅玩",
                    color: .green,
                    onTap: onHostTapped
                )
                
                // Guest tile
                RoleTile(
                    icon: "👥",
                    title: "我想当房客",
                    description: "输入房主提供的邀请码加入游戏世界",
                    color: .blue,
                    onTap: onGuestTapped
                )
            }
        }
    }
}

struct RoleTile: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(icon)
                .font(.system(size: 60))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onTap()
            }
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: color)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let title: String
    let message: String
    let onCancel: () -> Void
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            // Loading spinner
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            Button("取消") {
                onCancel()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Host Result View

struct HostResultView: View {
    let roomInfo: RoomInfo?
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Success icon
            Text("✅")
                .font(.system(size: 80))
            
            VStack(spacing: 16) {
                Text("房间创建成功")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                if let roomInfo = roomInfo {
                    // Room code display
                    VStack(spacing: 12) {
                        Text("邀请码")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(roomInfo.roomCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    )
                            )
                            .onTapGesture {
                                UIPasteboard.general.string = roomInfo.roomCode
                            }
                    }
                    
                    Text("点击邀请码可复制到剪贴板")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("请提醒您的朋友下载陶瓦联机，选择「我想当房客」并输入此邀请码")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            
            Button("关闭房间") {
                onClose()
            }
            .buttonStyle(PrimaryButtonStyle(color: .red))
        }
    }
}

// MARK: - Guest Result View

struct GuestResultView: View {
    let roomInfo: RoomInfo?
    let onLeave: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Success icon
            Text("🎮")
                .font(.system(size: 80))
            
            VStack(spacing: 16) {
                Text("成功加入房间")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("请启动 Minecraft，选择多人游戏，双击进入陶瓦联机大厅")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                if let roomInfo = roomInfo,
                   let address = roomInfo.serverAddress {
                    VStack(spacing: 8) {
                        Text("备用联机地址")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(address)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .onTapGesture {
                                UIPasteboard.general.string = address
                            }
                    }
                    
                    Text("点击地址可复制到剪贴板")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Button("退出房间") {
                onLeave()
            }
            .buttonStyle(PrimaryButtonStyle(color: .orange))
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let title: String
    let message: String
    let onRetry: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Error icon
            Text("❌")
                .font(.system(size: 80))
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            HStack(spacing: 16) {
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(PrimaryButtonStyle(color: .blue))
                
                Button("返回主页") {
                    onBack()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white.opacity(0.1))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    MainView()
}