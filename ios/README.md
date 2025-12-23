# iOS Terracotta Project

Terracotta iOS 平台实现，基于 ZeroTier libzt 框架。

## 项目结构

```
ios/
├── Package.swift                           # Swift Package 配置
├── Info.plist                             # 应用信息配置
├── Sources/                               # 源代码目录
│   ├── TerracottaCore/                     # 核心功能模块
│   │   ├── TerracottaCore.swift           # 主入口
│   │   ├── NetworkManager.swift           # 网络管理
│   │   ├── VPNManager.swift               # VPN 管理
│   │   ├── StateManager.swift             # 状态管理
│   │   ├── RoomManager.swift              # 房间管理
│   │   └── Native/                        # 原生代码桥接
│   │       ├── BridgingHeader.h           # Objective-C 桥接头文件
│   │       ├── terracotta.h               # Rust FFI 头文件
│   │       └── terracotta.c               # C 包装代码
│   └── TerracottaUI/                      # UI 模块
│       ├── Views/                         # 视图组件
│       │   ├── MainView.swift             # 主界面
│       │   ├── HostView.swift             # 房主界面
│       │   ├── GuestView.swift            # 房客界面
│       │   └── SettingsView.swift         # 设置界面
│       ├── ViewModels/                    # 视图模型
│       │   ├── MainViewModel.swift        # 主视图模型
│       │   ├── HostViewModel.swift        # 房主视图模型
│       │   └── GuestViewModel.swift       # 房客视图模型
│       └── Components/                    # UI 组件
│           ├── RoomTile.swift             # 房间卡片
│           ├── LoadingView.swift          # 加载视图
│           └── ResultView.swift           # 结果视图
├── Tests/                                 # 测试代码
│   ├── TerracottaCoreTests/
│   └── TerracottaUITests/
├── Extensions/                            # Network Extension
│   ├── PacketTunnelProvider.swift         # 数据包隧道提供者
│   └── NetworkExtension.entitlements      # Network Extension 权限
├── Frameworks/                            # 第三方框架
│   └── zt.framework/                      # ZeroTier 框架
└── Scripts/                               # 构建脚本
    ├── build.sh                          # 构建脚本
    └── setup.sh                          # 环境设置脚本
```

## 依赖项

### 系统框架
- NetworkExtension
- SystemConfiguration
- Combine
- SwiftUI

### 第三方库
- ZeroTier libzt framework
- swift-log
- swift-combine-extensions

## 构建要求

- iOS 15.0+
- Xcode 14.0+
- Swift 5.9+

## 权限配置

应用需要以下权限：
- 网络扩展权限 (Network Extension)
- 本地网络访问权限
- 后台网络认证权限