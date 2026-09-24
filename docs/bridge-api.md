# 桥接接口说明（Bridge API）

> 本文档定义 Pho 中 **Dart ↔ Go ↔ 原生**的通信契约、边界与生命周期。
> 术语保留英文，说明使用中文。

---

## 1. 三条链路的分工

Pho 的跨语言通信**不是一条链路**，而是三条，各自职责必须分清：

| 链路 | 方向 | 端口 / 名称 | 负责 |
|---|---|---|---|
| ① **gRPC** | Dart → Go | `127.0.0.1:50051`（嵌入式实际端口动态分配） | **控制面**：配置存储、查询列表、筛选未上传、删除 |
| ② **HTTP** | Dart → Go | `127.0.0.1:10001`（同上动态分配） | **数据面**：上传 / 下载 / 缩略图 / Range 流式播放 |
| ③ **Platform Channel** | Dart ↔ Kotlin/Swift | `com.ZenithLiteAura.app.pho/*` | **原生能力**：启动 Go、通知、后台任务、屏幕常亮 |

### 1.1 为什么必须分开

- **控制面与数据面分离**：大文件传输走 HTTP（可流式、可 Range），配置与查询走 gRPC（强类型、有 schema）。不要为了「统一」把文件塞进 gRPC。
- **原生能力与业务逻辑分离**：Channel 只暴露**操作系统能力**，不承载业务规则。业务一律在 Go 侧。

### 1.2 明确边界

| 约束 | 说明 |
|---|---|
| `app/` 不得直连 Go | 所有 gRPC/HTTP 调用必须经 `bridge/`，由桥接层统一处理地址、超时、错误映射 |
| `core/` 不得感知 UI | Go 代码中不允许出现「通知」「页面」「主题」等概念 |
| Channel 不含业务 | Kotlin/Swift 的 handler 只做系统 API 适配，不做业务流程判断 |
| 类型转换只在 `bridge/` | Dart 与 Go 之间的 DTO ↔ gRPC message 转换集中在一处 |

---

## 2. 三种跨语言方案的使用情况

| 方案 | 是否使用 | 说明 |
|---|---|---|
| **gomobile（AAR / xcframework）** | ✅ **使用中** | Go 经 `gomobile bind` 编译为 `server.aar`（Android）与 `RUN.xcframework`（iOS），**随应用一起打包**，在进程内运行 |
| **Platform Channel** | ✅ **使用中** | 见第 3 节 |
| **FFI（`dart:ffi` 直调）** | ❌ **未使用** | 当前**没有任何** FFI 调用。Go 不是以 `.so` + FFI 方式接入的；`c-shared` 构建产物（`server/clib`）仅用于桌面端预留 |

> **重要**：不存在「Dart 通过 FFI 调 Go」的路径。若未来需要零拷贝或高频小调用，再单独评估 FFI，**不要**在现有 gRPC/HTTP 链路上叠加 FFI 旁路。

---

## 3. Platform Channel 清单

三个通道，名称均在 `com.ZenithLiteAura.app.pho/` 命名空间下（**与 applicationId `com.ZenithLiteAura.app.pho` 不一致，属待修正项**，见 `style-guide.md` 差距清单）。

### 3.1 `com.ZenithLiteAura.app.pho/RunGrpcServer`

| 项 | 内容 |
|---|---|
| 提供方 | Android：`MainActivity.kt`；iOS：`AppDelegate.swift`（foreground + headless **双注册**） |
| 方法 | `RunGrpcServer`（无参） |
| 返回值 | 字符串 `"<grpcPort>,<httpPort>"` |
| 方法 | `scanFile`（`path` / `volumeName` / `relativePath` / `mimeType`）—— 仅 Android |
| 用途 | 启动内嵌 Go 服务端并返回实际监听端口 |

**约定**：两个端口由 Go 侧在 `10000-20000` 区间自动扫描分配，Dart 侧**不得假设固定端口**，必须使用返回值。

### 3.2 `com.ZenithLiteAura.app.pho/notifications`

| 项 | 内容 |
|---|---|
| 提供方 | Android：`MainActivity.kt`；iOS：`AppDelegate.swift` |
| 方法 | `requestAuthorization` / `checkAuthorizationStatus` / `sendLocalNotification` / `keepScreenOn` |
| 参数 | `sendLocalNotification`: `{title, body, isPassive}`；`keepScreenOn`: `{enable: bool}` |
| 用途 | 通知权限与发送、同步期间保持屏幕常亮 |

**历史教训（务必保留此约定）**：`keepScreenOn` 在两端都走**自建 Channel**，不使用 `wakelock_plus`。
原因是该插件的 Dart 端与 Android 端 pigeon 通道名不一致（`wakelock_plus_platform_interface` 1.6.0 加了包名前缀，而 `wakelock_plus` 1.1.4 仍用旧名），调用必定抛 `channel-error`。
**任何新增的原生能力都优先考虑并入本通道**，而不是引入新的第三方插件。

### 3.3 `com.ZenithLiteAura.app.pho/backgroundSync`

| 项 | 内容 |
|---|---|
| 提供方 | **仅 iOS**（`AppDelegate.swift`，注册在 **headless engine** 上） |
| 用途 | 系统 `BGProcessingTask` 触发后台同步时，Dart 与原生协商「完成 / 取消」 |
| Channel 归属 | `background_sync_entrypoint.dart`（headless 入口） |

**Android 不使用本通道**：Android 侧后台同步走 `sync_timer.dart` 的 `Timer.periodic` / 定时模式。

### 3.4 Headless engine 的注册差异（易踩坑）

iOS 的后台同步运行在**独立的 headless FlutterEngine** 中。Flutter 官方限制：headless engine **不会自动注册插件**，必须显式调用 `GeneratedPluginRegistrant.register`。

由此产生一条硬性约定：

> **凡是在 headless 入口（`background_sync_entrypoint.dart`）中要用的原生能力，都必须在 headless engine 上重新注册通道与插件。**

`AppDelegate` 通过 `registerAppChannels(on:)` 复用了同一套注册逻辑，新增通道时应挂进该函数，避免前台可用、后台失效。

---

## 4. 接口定义规范

1. **`proto/img_syncer.proto` 是唯一数据源**。新增/修改 RPC 一律先改 proto，再执行 `protoc` 生成两侧代码。
2. **生成物禁止手改**：`proto/*.pb.go`、`lib/proto/*.dart` 均为生成代码。
3. **命名**：RPC 用 `VerbNoun`（如 `SetDriveWebdav`、`ListByDate`）；message 用 `XxxRequest` / `XxxResponse`。
4. **响应信封**：既有约定为每个 Response 携带 `bool success` + `string message`（见第 5 节演进）。
5. **HTTP 侧的自定义头**（数据面契约，务必与 proto 同步维护）：

| Header | 说明 |
|---|---|
| `Image-Date` | 时间戳，格式 `2006:01:02 15:04:05` |
| `Image-Encrypt-Type` | `AES_128_CFB` / `AES_256_GCM` / 空表示不加密 |
| `Image-Encrypt-Password` | 加密口令 |
| `Image-Is-Live-Photo` | 布尔字符串 |

---

## 5. 错误处理规范

### 5.1 现状

- gRPC：统一 `success = false` + `message`（人类可读字符串，语言混杂）。
- HTTP：非 200 状态码 + 响应体文本。
- 上限：服务端单请求上传体 **8 GiB**（`core/api/http.go` 的 `maxUploadSize`），该值经 `Ping` 下发给客户端，客户端**上传前预检**。

**已知缺陷**：超限时 Go 的 http server 会因请求体未读完而直接关闭连接，客户端只能收到 `Broken pipe`、拿不到 413。因此**客户端必须在上传前自行预检**，不能依赖服务端报错。

### 5.2 目标：错误码 + 用户可读消息

```
错误码（英文大写下划线，稳定不变） + 用户可读消息（中文，见 style-guide.md）
```

建议错误码分段：

| 段 | 领域 | 示例 |
|---|---|---|
| `STORAGE_*` | 存储配置与连接 | `STORAGE_UNREACHABLE`、`STORAGE_AUTH_FAILED`、`STORAGE_PATH_INVALID` |
| `UPLOAD_*` | 上传 | `UPLOAD_TOO_LARGE`、`UPLOAD_INTERRUPTED`、`UPLOAD_TIMEOUT` |
| `DOWNLOAD_*` | 下载 | `DOWNLOAD_NOT_FOUND`、`DOWNLOAD_RANGE_UNSUPPORTED` |
| `DRIVE_*` | 驱动层 | `DRIVE_UNIMPLEMENTED`、`DRIVE_READ_ONLY` |
| `BRIDGE_*` | 桥接与通道 | `BRIDGE_CHANNEL_UNAVAILABLE`、`BRIDGE_SERVER_START_FAILED` |
| `UNKNOWN` | 兜底 | — |

**兼容策略**：在 Response 中**新增** `string error_code` 字段，保留既有 `success` / `message` 不动，客户端逐步迁移，避免破坏性变更。

**已有实现可参考**：客户端已把底层异常归一为用户可读文案（`describeUploadError`），这是本规范的雏形，应上移到 `bridge/` 并统一。

---

## 6. 生命周期管理

### 6.1 Go 服务端

| 阶段 | 行为 |
|---|---|
| 启动 | Dart `Global.init()` → Channel `RunGrpcServer` → Go 在 `10000-20000` 扫描可用端口 → 返回 `"grpcPort,httpPort"` |
| 就绪 | Dart 用返回端口构造 gRPC client 与 `httpBaseUrl` |
| 保活 | `checkServer()` 发 `Ping`；**60 秒去抖**，避免频繁探测 |
| 重启 | `Ping` 失败 → 重新调用 `RunGrpcServer` → 断开旧 client 重建 |
| 线程模型 | Go 侧为多 worker + 队列；`drive` 单例可热替换（`SetDrive`） |

**约束**：端口是动态的，禁止在任何地方硬编码 `50051` / `10001`（现有代码中存在占位默认值，仅用于初始化前占位，不得用于实际请求）。

### 6.2 应用前后台

| 事件 | 现有行为 |
|---|---|
| 进入后台 | `stateModel.needStopSync = true`（停止同步） |
| 回到前台 | 重置 `needStopSync`；**清空 `lastAliveTime` 强制探测**（绕过 60s 去抖）；必要时触发云端刷新 |
| 后台定时同步 | Android：`Timer.periodic` / 定时点；iOS：`BGProcessingTask` + headless engine |

### 6.3 桥接层生命周期职责（目标）

`bridge/` 需要集中管理：

1. Go server 的启动、探测、重启与端口缓存；
2. gRPC client 与 HTTP client 的创建与释放；
3. Channel 的注册（**含 headless engine 的重复注册**）；
4. 前后台切换时的探测与订阅变更。

**现状**：上述职责散落在 `global.dart`、`run_server.dart`、`checkServer()` 与各原文件里，是后续重构（步骤 C）的主要目标。

---

## 7. 新增跨语言能力的检查清单

引入任何新的原生能力或接口前，逐条确认：

- [ ] 属于哪条链路？（控制面 → gRPC；数据面 → HTTP；系统能力 → Channel）
- [ ] 是否必须新增插件？**优先并入既有 `notifications` 通道**
- [ ] 契约是否先在 proto / 文档中定义？
- [ ] 错误是否给出了**错误码 + 中文可读消息**？
- [ ] headless（iOS 后台）路径是否需要重新注册？
- [ ] 是否违反了第 1.2 节的边界约束？
- [ ] 端口、生命周期是否走 `bridge/` 统一管理？