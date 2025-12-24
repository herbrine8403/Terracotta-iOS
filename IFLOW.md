# Terracotta | 陶瓦联机

Terracotta 是一个基于 EasyTier 和 ZeroTier 开发的 Minecraft: Java Edition 联机助手，为玩家提供开箱即用的联机功能。项目针对 Minecraft 做了大量优化，尽量降低操作门槛并集成了 HMCL 启动器支持。

## 项目概述

### 核心功能
- **一键联机**: 无需复杂配置，轻松创建或加入 Minecraft 房间
- **跨平台支持**: 支持 Windows、Linux、macOS、FreeBSD、Android 和 iOS 平台
- **自动发现**: 自动扫描本地 Minecraft 服务器
- **房间系统**: 基于邀请码的房间管理机制
- **HMCL 集成**: 与 HMCL 启动器深度集成

### 技术架构
- **后端**: Rust 编写的高性能网络服务
- **前端**: 响应式 Web 界面（桌面端）和 SwiftUI（iOS端）
- **网络层**: 
  - 桌面/Android: 基于 EasyTier 的 P2P 网络连接
  - iOS: 基于 ZeroTier libzt 的 P2P 网络连接
- **协议支持**: 多种房间协议（Terracotta Legacy、PCL2CE、Experimental）

## 项目结构

```
Terracotta/
├── src/                    # 主要源代码
│   ├── main.rs            # 主程序入口（桌面平台）
│   ├── lib.rs             # 库入口（Android 平台）
│   ├── controller/        # 控制器模块
│   │   ├── api.rs         # API 接口
│   │   ├── states.rs      # 状态管理
│   │   └── rooms/         # 房间协议实现
│   ├── easytier/          # EasyTier 集成
│   ├── server/            # HTTP 服务器
│   ├── scaffolding/       # 脚手架服务
│   └── mc/                # Minecraft 相关功能
├── web/                   # Web 前端
│   ├── _.html            # 主页面
│   ├── font-awesome.css  # 样式文件
│   └── webfonts/         # 字体文件
├── build/                 # 构建相关文件
│   ├── linux/            # Linux 平台资源
│   ├── macos/            # macOS 平台资源
│   ├── windows/          # Windows 平台资源
│   └── publish/          # 发布脚本
├── ffi/                   # Android JNI 接口
├── ios/                   # iOS 平台实现
│   ├── Package.swift      # Swift Package 配置
│   ├── Info.plist         # 应用信息配置
│   ├── Sources/           # 源代码目录
│   │   ├── TerracottaCore/ # 核心功能模块
│   │   │   ├── TerracottaCore.swift # 主入口
│   │   │   ├── VPNManager.swift   # VPN 管理
│   │   │   └── Native/            # 原生代码桥接
│   │   └── TerracottaUI/  # UI 模块
│   │       ├── Views/     # 视图组件
│   │       └── ViewModels/# 视图模型
│   ├── Extensions/        # Network Extension
│   ├── Scripts/           # 构建脚本
│   └── Tests/             # 测试代码
├── timestamp/             # 编译时间戳子模块
├── zerotier-sockets-apple-framework/ # ZeroTier Apple 框架
└── .github/workflows/     # CI/CD 配置
```

## 开发环境设置

### 前置要求
- Rust 2024 Edition (nightly toolchain)
- Swift 5.9+ (iOS 开发)
- Xcode 14.0+ (iOS 开发)
- Android SDK (Android 开发)

### 构建命令

#### 桌面平台
```bash
# 开发构建
cargo +nightly build

# 发布构建
cargo +nightly build --release

# 运行程序
cargo +nightly run
```

#### Android 平台
```bash
# 设置 Android SDK
export ANDROID_NDK_HOME=/path/to/ndk
export PATH="$PATH:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"

# 构建 Android 库
cargo +nightly ndk build --release --lib --target aarch64-linux-android
```

#### iOS 平台
```bash
# iOS 环境设置
cd ios
chmod +x Scripts/setup.sh
./Scripts/setup.sh

# 构建 iOS 应用
chmod +x Scripts/build.sh
./Scripts/build.sh build
```

### 开发服务器
```bash
# 启动开发服务器（会自动打开浏览器）
cargo +nightly run

# HMCL 模式
cargo +nightly run -- --hmcl /path/to/socket/file
```

## 核心模块

### 控制器 (Controller)
- **状态管理**: 管理应用程序的各种状态（等待、扫描、连接等）
- **房间管理**: 处理房间创建、加入和生命周期
- **API 接口**: 提供 RESTful API 供前端调用

### 网络集成
- **桌面/Android (EasyTier)**: 管理 EasyTier 进程和网络连接
- **iOS (ZeroTier)**: 管理 ZeroTier libzt 连接
- **VPN 集成**: 处理 VPN 服务请求（Android 和 iOS）
- **节点发现**: 发现和管理网络节点

### 服务器 (Server)
- **HTTP 服务**: 提供 Web 界面和 API
- **静态资源**: 服务前端静态文件
- **状态同步**: 实时同步应用状态到前端

### 脚手架 (Scaffolding)
- **配置文件**: 管理配置文件和用户设置
- **服务器**: 提供脚手架服务
- **客户端**: 客户端功能实现

## API 文档

### 状态管理 API
```
GET /state          # 获取当前状态
POST /state/ide     # 重置到等待状态
POST /state/scanning # 开始扫描
POST /state/guesting # 加入房间
```

### 元数据 API
```
GET /meta           # 获取程序元数据
GET /log            # 获取日志文件
POST /panic         # 触发程序崩溃（调试用）
```

## iOS 特定实现

### iOS 架构
iOS 版本采用了不同的技术栈：
- **网络层**: ZeroTier libzt 框架（替代 Android 版本的 EasyTier）
- **UI 框架**: SwiftUI + Combine（现代化响应式界面）
- **VPN 集成**: Network Extension 框架（iOS 原生 VPN 支持）
- **桥接技术**: Objective-C + Rust FFI（高效的原生代码集成）

### iOS 特性
- 支持 iOS 15.0+
- 支持 iPhone 和 iPad
- 现代化 SwiftUI 界面
- 自动网络发现
- 实时状态同步

## 部署和发布

### 自动构建
项目使用 GitHub Actions 进行自动化构建，支持以下平台：
- Windows (x86_64, ARM64)
- Linux (x86_64, ARM64, RISC-V64, LoongArch64)
- macOS (x86_64, ARM64)
- FreeBSD (x86_64)
- Android (ARM, ARM64, x86, x86_64)
- iOS (ARM64, x86_64)

### 发布流程
1. 代码推送到主分支触发自动构建
2. 构建完成后自动上传到多个平台
3. 创建 GitHub Release（仅限版本标签）

### 手动发布
```bash
# 创建发布版本
gh release create v1.0.0 --generate-notes

# 或使用 GitHub Actions 手动触发
```

## 配置文件

### 应用配置
- **工作目录**: 临时目录（Linux/Windows）或用户目录（macOS）
- **日志文件**: `application.log`
- **机器 ID**: `machine-id`

### 网络配置
- **默认端口**: 13448（脚手架服务）
- **EasyTier 版本**: v2.4.6（桌面/Android）
- **网络协议**: 支持 IPv4/IPv6

## 故障排除

### 常见问题
1. **端口占用**: 检查 13448 端口是否被占用
2. **防火墙**: 确保防火墙允许程序通信
3. **EasyTier/ZeroTier 崩溃**: 查看日志文件获取详细错误信息
4. **网络连接**: 检查网络连接和 DNS 设置
5. **iOS VPN 权限**: 确保授予网络扩展权限

### 调试功能
- **日志导出**: Shift+双击标题栏导出日志
- **调试模式**: Alt+双击标题栏进入调试模式
- **状态检查**: 访问 `/state` 端点查看详细状态

## 许可证

本项目使用 [GNU Affero General Public License v3.0 or later](LICENSE) 许可证，并附有以下例外：

> **AGPL 的例外情况:**
>
> 作为特例，如果您的程序通过以下方式利用本作品，则相应的行为不会导致您的作品被 AGPL 协议涵盖。
> 1. 您的程序通过打包的方式包含本作品未经修改的二进制形式，而没有静态或动态地链接到本作品；或
> 2. 您的程序通过本作品提供的进程间通信接口（如 HTTP API）与未经修改的本作品应用程序进行交互，且在您的程序用户界面明显处标识了本作品的版权信息。

## 贡献指南

### 代码规范
- 使用 Rust 2024 Edition
- 遵循 Rust 官方代码风格
- 遵循 Swift 代码规范（iOS 部分）
- 添加适当的注释和文档

### 提交流程
1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

### 测试
```bash
# 运行测试
cargo +nightly test

# 运行特定测试
cargo +nightly test --test integration_test

# iOS 测试
cd ios
./Scripts/build.sh test
```

## 社区和支持

- **GitHub Issues**: [报告问题](https://github.com/burningtnt/Terracotta/issues)
- **QQ 群**: [加入社区](https://docs.hmcl.net/groups.html)
- **文档**: [在线文档](https://docs.hmcl.net/terracotta/)

## 版本历史

### 当前版本
- **版本号**: 0.0.0-snapshot
- **EasyTier**: v2.4.6
- **Rust Edition**: 2024

### 更新内容
- 支持多平台部署
- 优化网络连接稳定性
- 改进用户界面体验
- 增强错误处理机制
- 添加 iOS 平台支持（采用 ZeroTier libzt 替代 EasyTier）