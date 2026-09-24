# 贡献指南 (Contributing Guide)

感谢你愿意为 Pho 贡献！无论是修 bug、做功能、写文档还是报告问题，都非常欢迎。

## 项目简介

Pho 是一个**无服务端**的照片浏览与同步应用：

- **Flutter 客户端**（`lib/app/`）：界面、主题与状态管理
- **平台桥接**（`lib/bridge/`）：平台通道、存储客户端、通知、后台入口
- **核心逻辑**（`lib/core/`）：同步调度与工具
- **嵌入式 Go 后端**（`core/`）：经 gomobile 编译进应用，提供 gRPC 控制接口 + HTTP 文件传输
- 手机**直连** SMB / WebDAV / NFS，无数据库、无中间服务器，存储文件系统即数据库（按 `YYYY/MM/DD/` 组织）

## 环境要求

| 工具 | 版本 |
|------|------|
| Flutter | 3.41.4 (stable) |
| Dart | 3.11.1 |
| Go | 1.25+（toolchain go1.25.4） |
| JDK | 17 |
| Android SDK | compileSdk 36 |
| Android NDK | 任意受支持版本（用于 gomobile bind） |
| protoc | + protoc-gen-go@v1.27.1、protoc-gen-go-grpc@v1.1.0、Dart protoc_plugin@21.1.2 |

## 快速开始（本地构建）

```bash
# 1. 生成 protobuf 代码（Go + Dart stubs）
make prebuild      # 首次运行，安装 protoc 插件
make protobuf

# 2. 构建嵌入式 Go 服务端（Android AAR）
make server-aar    # -> android/app/libs/server.aar

# 3. 运行或构建应用
flutter run        # debug 模式
make apk           # release APK
```

> ⚠️ **重要**：`flutter run` / `flutter build apk` 不会自动构建 AAR。跳过 `make server-aar` 时应用能安装，但内嵌 Go 服务端无法启动（同步功能不可用）。

> Windows 构建 `make server-windows` 需要手动 `sed` + `dlltool` 后处理，建议在 Linux / WSL 下开发。

## 代码结构速览

| 目录 | 内容 | 常见改动场景 |
|------|------|-------------|
| `lib/app/` | Flutter 界面、主题、状态 | 页面、交互、状态管理（`lib/app/state/state_model.dart`） |
| `lib/bridge/` | 平台桥接与存储客户端 | 平台通道、通知、`lib/bridge/storage/` |
| `lib/core/` | 同步调度与工具 | `lib/core/sync/`、`lib/core/sync_timer.dart` |
| `core/api/` | gRPC 服务实现 + HTTP 文件处理 | 新增接口 |
| `core/imgmanager/` | 上传 / 下载 / 缩略图 | 同步行为改动 |
| `core/drive/` | 存储后端（smb / webdav / nfs） | 新增存储类型 |
| `proto/` | protobuf 定义（唯一数据源） | 新增 RPC 时改这里 |
| `test/` | Go 集成测试 + Dart 单元/组件测试 | 测试 |

**约定**：

- `lib/proto/*` 与 `proto/*.pb.go` 是**生成代码，不要手改**；改 `proto/img_syncer.proto` 后执行 `make protobuf`
- 存储布局：`YYYY/MM/DD/{timestamp}_{filename}`，缩略图在 `.thumbnail/` 镜像目录，Live Photos 在 `live_<name>/` 子目录
- 状态管理用 `provider` + `ChangeNotifier` 单例，导航用 `Navigator.push(MaterialPageRoute(...))`，无路由库
- UI 尺寸与配色请使用设计 token（`lib/app/theme/design_tokens.dart`），不要写死数值

## 如何提交 Issue

请使用仓库自带的 issue 模板（Bug 报告 / 功能建议），并尽量提供：

- 设备型号 + 系统版本 + Pho 版本号
- 存储类型（SMB / WebDAV / NFS）与配置方式
- 复现步骤 + 期望行为 + 实际行为
- 相关截图，或从「设置 → 日志与诊断」导出的日志

**提问前**先搜索已有 issue，避免重复。使用类问题请先看 README 的「简介」与「构建」章节。

## 如何提交 Pull Request

1. **Fork** 本仓库并克隆到本地
2. 创建功能分支：`git checkout -b fix/xxx` 或 `git checkout -b feat/xxx`
3. 做出改动并**自测通过**（见下方「测试」）
4. 提交（提交信息用中文，风格参考现有 `git log`，如 `feat: 支持xxx` / `fix: 修复xxx`）
5. 推送到你的 fork，创建 PR
6. 在 PR 描述中说明：**改了什么、为什么改、如何测试的、是否影响现有同步逻辑**

> PR 尽量小而聚焦：一个 PR 解决一个问题。大改动请先开 issue 讨论方案，避免白做。

## 代码风格

- **Dart**：遵循 `analysis_options.yaml`（`package:flutter_lints`），提交前运行 `dart analyze` 确认无新增告警
- **Go**：`gofmt` 格式化，遵循现有包结构与命名（如 `ImgManager`、`StorageDrive` 接口）
- **注释**：使用中文
- 不要修改生成代码，不要引入无必要的第三方依赖

## 测试

```bash
make test      # Go 集成测试：需要 Docker（拉起 SMB / WebDAV / NFS 容器）
flutter test   # Dart 单元与组件测试
```

- 涉及同步、存储的改动务必跑 `make test`
- 纯 UI 改动至少真机跑一遍：配置存储 → 同步几张照片 → 云端浏览

## 新手从哪开始？

- 带有 **`good first issue`** 标签的 issue 最适合入门：任务边界清晰、改动范围小
- 常见简单任务类型：
  - **i18n**：新增语言支持——只需加 ARB 文件并注册
  - **文档**：README、FAQ、注释完善
  - **UI 细节**：间距 / 配色 / 交互微调

## 交流渠道

- GitHub Issues：Bug 报告与功能建议