# Terracotta-iOS 项目上下文

## 项目概述

Terracotta-iOS 是一款基于 **EasyTier** P2P 组网框架的 iOS VPN 应用。它允许用户创建或加入虚拟房间，实现设备间的点对点网络连接。

### 核心功能
- 创建/加入虚拟房间进行 P2P 组网
- VPN 隧道连接管理
- 日志查看与配置管理
- iCloud 配置同步支持

## 技术栈

| 技术 | 用途 |
|------|------|
| Swift / SwiftUI | iOS 前端 UI 开发 |
| Rust | 核心网络逻辑 (FFI) |
| EasyTier | P2P 组网底层框架 |
| XcodeGen | Xcode 项目配置生成 |
| NetworkExtension | iOS VPN 隧道实现 |

## 项目结构

```
Terracotta-iOS/
├── project.yml              # XcodeGen 项目配置
├── Core/                    # Rust 核心库
│   ├── Cargo.toml          # Rust 依赖配置
│   └── src/lib.rs          # FFI 接口实现
├── Terracotta/              # 主应用
│   ├── TerracottaApp.swift # 应用入口
│   ├── ContentView.swift   # 主视图
│   ├── Components/         # UI 组件 (待开发)
│   ├── Models/             # 数据模型 (待开发)
│   ├── Utils/              # 工具类
│   │   ├── NetworkExtensionManager.swift  # VPN 连接管理
│   │   ├── ProfileStore.swift             # 配置存储
│   │   └── LogTailer.swift                # 日志追踪
│   └── Views/              # 视图层
│       ├── DashboardView.swift   # 仪表盘
│       ├── RoomsView.swift       # 房间管理
│       ├── SettingsView.swift    # 设置页面
│       └── LogView.swift         # 日志页面
├── TerracottaNetworkExtension/    # 网络扩展
│   └── PacketTunnelProvider.swift # VPN 隧道提供者
├── TerracottaShared/              # 共享框架
│   └── TerracottaShared.swift     # 共享类型定义
└── .github/workflows/
    └── build.yml            # CI/CD 配置
```

## 架构说明

### 四个主要 Target

1. **Terracotta** (主应用)
   - Bundle ID: `site.yinmo.terracotta`
   - SwiftUI 应用，包含 UI 和业务逻辑

2. **TerracottaNetworkExtension** (网络扩展)
   - Bundle ID: `site.yinmo.terracotta.TerracottaNetworkExtension`
   - 实现 `NEPacketTunnelProvider`，处理 VPN 隧道

3. **TerracottaShared** (共享框架)
   - 包含主应用和网络扩展共享的类型定义
   - 定义了 `TerracottaOptions`、`ConnectionStatus` 等核心类型

4. **Core** (Rust 核心库)
   - 编译为静态库供网络扩展调用
   - 提供 FFI 接口供 Swift 调用

### Rust FFI 接口

| 函数 | 说明 |
|------|------|
| `run_network_instance(cfg_str, err_msg)` | 启动网络实例 |
| `stop_network_instance()` | 停止网络实例 |
| `register_stop_callback(callback, err_msg)` | 注册停止回调 |
| `register_running_info_callback(callback, err_msg)` | 注册运行信息回调 |
| `create_room(room_name, err_msg, result)` | 创建房间 |
| `join_room(room_code, err_msg)` | 加入房间 |

## 构建与运行

### 环境要求
- Xcode 16.0+
- iOS 14.5+ Deployment Target
- Rust 工具链 (用于 Core 库)
- XcodeGen (`brew install xcodegen`)

### 构建步骤

```bash
# 1. 生成 Xcode 项目
xcodegen generate

# 2. 构建 (无代码签名)
xcodebuild -project Terracotta.xcodeproj \
  -scheme Terracotta \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive -archivePath build/Terracotta.xcarchive
```

### Rust Core 库构建

```bash
# 添加 iOS 目标
rustup target add aarch64-apple-ios

# 构建静态库
cd Core
cargo build --release --target aarch64-apple-ios
```

## 开发约定

### Swift 代码风格
- 使用 SwiftUI 声明式 UI
- `@EnvironmentObject` 用于依赖注入
- `@Published` 属性用于状态管理
- 遵循 MVVM 模式

### 文件组织
- Views: 视图层组件
- Utils: 工具类和 Manager
- Components: 可复用 UI 组件
- Models: 数据模型

### 命名规范
- 视图: `*View.swift` (如 `DashboardView.swift`)
- 管理器: `*Manager.swift` (如 `NetworkExtensionManager.swift`)
- Store: `*Store.swift` (如 `ProfileStore.swift`)

### 日志
- 使用 `os_log` 进行日志记录
- 日志级别: `trace`, `debug`, `info`, `warn`, `error`

## 关键类型

### ConnectionStatus
```swift
enum ConnectionStatus {
    case disconnected  // 已断开
    case connecting    // 连接中
    case connected     // 已连接
    case error         // 错误
}
```

### TerracottaOptions
```swift
struct TerracottaOptions {
    var config: String       // 配置字符串
    var ipv4: String?        // IPv4 地址
    var ipv6: String?        // IPv6 地址
    var mtu: Int?            // MTU 值
    var routes: [String]     // 路由列表
    var logLevel: LogLevel   // 日志级别
    var magicDNS: Bool       // Magic DNS
    var dns: [String]        // DNS 服务器
}
```

## App Group 与数据共享

- **App Group ID**: `group.site.yinmo.terracotta`
- **iCloud Container**: `iCloud.site.yinmo.terracotta`

主应用和网络扩展通过 App Group 共享 UserDefaults 和配置数据。

## CI/CD

项目使用 GitHub Actions 进行持续集成:
- 触发条件: push/PR 到 master 分支
- 运行环境: macOS-latest
- 构建产物: `Terracotta.app.zip`

## 注意事项

1. **代码签名**: 当前配置禁用了代码签名，正式发布时需要配置开发者证书
2. **Rust 库链接**: Core 库需要手动构建并链接到项目
3. **网络权限**: 需要在 entitlements 中配置网络权限
4. **VPN 权限**: 需要 Network Extension 权限
