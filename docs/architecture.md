# Pho 架构说明

> 本文档描述 Pho 的**当前架构**与**目标架构**，并给出两者之间的迁移路径。
> 术语保留英文，说明使用中文。

---

## 1. 当前架构

### 1.1 组成

Pho 是一个**无服务端**的照片查看与同步应用：手机直连 SMB / WebDAV / NFS，
存储的文件系统本身即数据库。代码由四部分组成：

| 部分 | 位置 | 语言 | 说明 |
|---|---|---|---|
| Flutter 应用 | `lib/` | Dart | UI、状态管理、业务编排 |
| 内嵌服务端 | `server/` | Go | 同步引擎、存储驱动、加密、缩略图 |
| Android 原生 | `android/app/src/main/kotlin/` | Kotlin | 通知、媒体扫描、gRPC server 启动 |
| iOS 原生 | `ios/Runner/` | Swift | 通知、屏幕常亮、后台任务 |

### 1.2 链路图

```
┌──────────────────────────────────────────────────────────┐
│ Flutter (Dart)                                           │
│  页面 / 状态 / 上传下载编排                                 │
└───┬───────────────┬──────────────────┬───────────────────┘
    │               │                  │
    │ ①gRPC :50051  │ ②HTTP :10001     │ ③Platform Channel
    │  (控制面)      │  (数据面)         │  (原生能力)
    ▼               ▼                  ▼
┌───────────────────────────┐  ┌──────────────────────────┐
│ 内嵌 Go 服务端             │  │ Kotlin / Swift 原生层     │
│ (gomobile 编译为 server.aar)│  │ 通知 / 媒体扫描 / 启动服务  │
│  ├ api/      gRPC + HTTP  │  └──────────────────────────┘
│  ├ imgmanager/ 核心编排    │
│  ├ drive/    smb/webdav/nfs│
│  └ run/      嵌入式入口     │
└───────────┬───────────────┘
            │ ④ 存储协议
            ▼
     SMB / WebDAV / NFS 等网络存储
```

三条链路各自的分工见 `bridge-api.md`。

### 1.3 现状问题清单

以下问题均在代码中可核对，是后续重构的依据：

| # | 问题 | 证据 |
|---|---|---|
| A1 | ~~**Platform Channel 命名与包名不一致**~~ **已修复** | 原为 `com.ZenithLiteAura.app.pho/*`，现已统一为 `com.ZenithLiteAura.app.pho/*`（见第 6 节执行记录） |
| A2 | **`lib/` 根目录平铺** | 顶层 20 个 `.dart` 文件与 11 个子目录混放，UI / 状态 / 存储 / 桥接未分层 |
| A3 | **桥接代码散落** | `run_server.dart`（启动 Go）、`background_sync_route.dart`（后台任务）、`util.dart`（屏幕常亮）分散在各处，无统一入口 |
| A4 | **错误处理只有字符串** | gRPC 层统一 `success + message`，无错误码，无法在 UI 侧区分处理 |
| A5 | **`print` 直用** | 14 处直接 `print(`，未走 `logger`，采集与分级失效 |
| A6 | **硬编码英文文案** | 6 处，如 `'Not implemented'`、`'Author'`、`'OK'`；与「文案统一中文」冲突 |
| A7 | **WebView / HTML 边界未成文** | `assets/html/login_success/` 经 Go 的 `//go:embed` 内嵌，属服务端资源；Dart 侧零 WebView 使用，但该定位从未写下来 |
| A8 | **两套存储配置实现的历史残留** | 已收敛为 `StorageConfigBody` 单一实现，但旧入口的引用关系需在文档中固化，防止回退 |

---

## 2. 目标架构

### 2.1 分层与职责

```
apps/                        薄壳：只做路由、状态、页面框架
  app/            Flutter 壳（路由、状态管理、通用 UI）
  native/         Android Kotlin(Compose/Miuix) + iOS SwiftUI
bridge/           桥接层：类型转换、错误映射、生命周期（不写业务）
core/             Go 核心：同步、存储、协议、加密、任务调度
web/              WebView 页面资源（仅补充，不承担核心 UI）
docs/             架构、接口、风格规范
scripts/          构建、发布、代码生成
```

| 层 | 职责 | 明确**不**做 |
|---|---|---|
| `core/` | 同步引擎、存储驱动、加密、任务调度、缩略图 | **不依赖任何 UI**；不感知 Flutter / Compose |
| `bridge/` | Dart↔Go 类型转换、错误码映射、Channel 协议、生命周期管理 | **不含业务逻辑**；不决定「同步什么」 |
| `app/` | 路由、状态管理、页面框架、通用 UI、文案 | **不直接调用 Go**；一律经 `bridge/` |
| `native/` | 原生质感组件（Miuix）、PlatformView 宿主 | 不承载核心业务；不复制 `app/` 的页面职责 |
| `web/` | WebView 页面（OAuth 等补充场景） | 不承担核心页面 |

### 2.2 依赖方向（唯一）

```
app ─┐
     ├──► bridge ──► core
native ┘
```

**禁止项**：

1. `core` **不得**反向依赖 `app` / `native` / `bridge`（Go 代码里不允许出现 UI 相关概念）。
2. `app` / `native` **不得**直连 Go（不允许绕过 `bridge` 自行拼 gRPC/HTTP 请求）。
3. `web` 不得成为业务逻辑的落点，只能是补充视图。
4. 跨层调用只能向下，不允许同层横向依赖。

### 2.3 目标目录结构

```
pho/
├── core/                       # Go 核心（现 server/）
│   ├── api/                    #   gRPC + HTTP 边界
│   ├── imgmanager/             #   核心编排
│   ├── drive/{smb,webdav,nfs}/ #   存储驱动
│   ├── run/                    #   gomobile 嵌入式入口
│   └── util/
├── bridge/                     # 桥接层
│   ├── dart/                   #   Dart 侧：gRPC client、Channel、类型映射
│   └── android/  ios/          #   原生侧：Channel handler（薄）
├── app/                        # Flutter 壳（现 lib/ 的分层重排）
│   ├── pages/                  #   页面
│   ├── state/                  #   状态模型
│   ├── widgets/                #   通用组件
│   └── theme/                  #   设计 token 与主题
├── native/                     # 原生 UI 层
│   └── android/                #   Kotlin + Compose + Miuix（POC 阶段）
├── web/                        # WebView 资源
├── docs/                       # 本文档所在
└── scripts/                    # 构建 / 发布 / 代码生成
```

### 2.4 迁移映射表

> 原则：**先移动、后改造**。每步只做一件事，保证可运行、可回滚。

| 现状 | 目标 | 备注 |
|---|---|---|
| `server/**` | `core/**` | 纯目录移动，Go import path 需整体替换 |
| `proto/` | `bridge/proto/` | 生成物位置随 proto 调整 |
| `lib/proto/` | `bridge/dart/proto/` | 生成代码 |
| `lib/storage/storage.dart`、`storage_interface.dart` | `bridge/dart/` | gRPC client 与 HTTP 传输属桥接 |
| `lib/run_server.dart` | `bridge/dart/` | 启动 Go 的 Channel 调用 |
| `lib/background_sync_route.dart`、`background_sync_entrypoint.dart` | `bridge/dart/` | 后台任务通道 |
| `lib/util.dart` 中的 `keepScreenOn` | `bridge/dart/` | 原生能力调用 |
| `lib/global.dart` | `app/state/` + `bridge/dart/` 拆分 | 全局变量与桥接初始化混在同一个文件 |
| `lib/state_model.dart`、`asset.dart` | `app/state/` | 状态模型 |
| `lib/gallery_body.dart`、`sync_body.dart`、`settings/**`、`*_route.dart` | `app/pages/` | 页面 |
| `lib/design_tokens.dart`、`theme.dart`、`settings/theme_controller.dart` | `app/theme/` | 设计系统 |
| `lib/logger/**` | `app/` 或 `bridge/dart/` | 采集器属应用能力；日志若需上报则经 bridge |
| `assets/html/` | `web/` | Go 内嵌资源位置调整 |
| `buildtools/` | `scripts/`（文档说明） | 本机工具链，已被 gitignore |

---

## 3. WebView / HTML 的定位

- **现状**：Dart 侧**没有任何 WebView 依赖与调用**。`assets/html/login_success/index.html` 由 `index.go` 通过 `//go:embed` 内嵌进 Go 二进制，供服务端 HTTP 处理器返回，属于**服务端资源**。
- **定位**：`web/` 仅用于**Flutter 难以原生实现的补充页面**（如第三方 OAuth 回跳页）。核心页面一律 Flutter 实现。
- **约束**：WebView 页面不得直接调用 Go 或访问本地凭据，需要数据时经 `bridge/` 提供。

---

## 4. 原生 UI（MIUI X / Miuix）的定位与可行性

### 4.1 定位

项目**已有一套 Flutter 自绘的 Miuix 风格**（`settings/theme_controller.dart` 的 `buildMiuixTheme()`：HyperOS 圆角卡片、紧凑布局、小米蓝强调色）。因此原生 Miuix 的定位是**补充**，而非替代：

> 原生 Miuix 仅用于 **Flutter 难以自绘**的部分（squircle 形状、真实模糊、官方质感动效），且限于**少量、低交互密度**的组件。大面积列表仍走 Flutter 自绘。

### 4.2 可行性评估结论

| 评估项 | 结论 |
|---|---|
| **依赖坐标** | `top.yukonga.miuix.kmp:miuix-ui` / `-preference` / `-icons` / `-blur` / `-squircle` / `-nav` / `-shader` |
| **最新稳定版** | **0.9.4**（2026-09-20 发布），Apache-2.0 |
| **上游状态** | 官方明示 **experimental**，API 可能不作通知地变更 ⚠️ |
| **库形态** | **Compose Multiplatform** 库，在纯 Android 工程中的 variant 解析需实测 |
| **本机 Android 前提** | AGP 8.11.1 / Kotlin 2.2.20 / Java 17 / compileSdk 36 / minSdk 24 —— **均满足** |
| **缺口** | 工程**未启用 Compose**（无 `buildFeatures.compose`、无 BOM、无 compose 插件），需新增三处配置 |
| **PlatformView 模式** | 优先 **TLHC**（Flutter Android 默认），异常时退 Hybrid Composition |
| **POC 建议** | **设置项列表**（直接用官方 `miuix-preference` 模块） |
| **工作量** | 约 1–2 天（含编译调试） |

### 4.3 风险

1. **上游 experimental**：需将 POC 隔离在 `native/` 内，Flutter 侧仅通过 `viewType` + `creationParams` 通信，替换成本可控。
2. **包体积**：引入 Compose 运行时 + Miuix 会增大 APK，需在 POC 阶段实测并设阈值。
3. **不重写现有页面**：已有自绘 Miuix 主题，重写收益低、风险高。
4. **iOS 本阶段不涉及**：Miuix 面向 Compose，iOS 侧另行评估 SwiftUI。

---

## 5. 演进节奏

1. 文档产出（本文档 + `bridge-api.md` + `style-guide.md`）—— **不动业务代码**
2. 评审确认
3. 小步重构，每步可运行、可回滚：
   - **A**：Dock 翻页动画（独立低风险，先行验证流程）
   - **B**：目录分层（纯移动，不改逻辑）
   - **C**：桥接层规范化（Channel 改名、错误码映射、生命周期收敛）
   - **D**：风格统一（格式化、文案、`print` → `logger`）
4. MIUI X POC（仅 Android，设置项列表）

**重点不是一次大重构，而是先把边界与风格定下来**，后续接入 MIUI X 才不至于越接越乱。

---

## 6. 执行记录

### 步骤 A：Dock 翻页动画 ✓

`main.dart` 的 `IndexedStack` → `PageView`（280ms / `Curves.easeOutCubic`）。
用 `children` 形式保证三个页面常驻、状态不丢；`NeverScrollableScrollPhysics` 禁止手动滑动。

### 步骤 B：目录分层 ✓（纯移动，未改逻辑）

**Dart 侧**（`lib/` 内部按层重组）：

| 层 | 路径 | 文件数 | 内容 |
|---|---|---|---|
| 应用层 | `lib/app/` | 41 | `pages/`（含 `settings/`、`onboarding/`、`desktop/`）、`state/`、`theme/`、`widgets/`、`logger/` |
| 桥接层 | `lib/bridge/` | 7 | `storage/`（gRPC/HTTP client）、`notifications/`、`run_server.dart`、`background_sync_*.dart`、`util.dart` |
| 核心层 | `lib/core/` | 4 | `sync/`（同步引擎）、`sync_timer.dart`、`hash_util.dart` |
| 生成代码 | `lib/l10n/`、`lib/proto/` | — | 保持原位（输出目录由 `l10n.yaml` / `make protobuf` 指定） |
| 入口 | `lib/main.dart` | 1 | Flutter 约定的入口位置 |

**Go 侧**：`server/` → `core/`，同步更新 Go import path、Makefile 中的构建路径、
`.gitignore`、`CONTRIBUTING.md`、`test/docker-compose.yml` 与 `buildtools/README.md` 的引用。

**与第 2.3 节目标结构的三处有意差异**：

1. Flutter 约定入口必须是 `lib/main.dart`，因此应用层落在 `lib/app/` 之下，而非顶层 `app/`。
2. `l10n/` 与 `proto/` 属生成代码：移动它们需同步改 `l10n.yaml` 的 `output-dir` 与
   `make protobuf` 的 `--dart_out` 参数。为避免生成链路出错，本轮**保持原位**，
   其分层归属由文档约定。
3. Makefile 的目标名（`server-aar` / `server-ios` / `server-linux` …）**未改名**：
   它们是命令接口，CI（`.github/workflows/go_test.yml` 的 `make server`）与文档均按此调用，
   改名收益低于破坏成本。注意区分：**目标名中的 "server" 指「服务端」，与目录名无关**。

**验证结果**：`flutter analyze` 零新增告警（问题总数与重构前一致）；
测试 `+127 -14`（14 项为既有失败，零回归）；`go build ./core/...` 通过；
AAR 重建成功；APK/AAB 构建成功；签名指纹不变（可覆盖升级）。