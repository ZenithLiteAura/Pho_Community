# 贡献指南 (Contributing Guide)

感谢你愿意为 Pho 开源版贡献！这个项目从 2023 年至今一直是单人维护，很需要社区的力量。无论是修 bug、做功能、写文档还是报告问题，都非常欢迎。

## 项目简介

Pho 是一个**无服务端**的照片查看与同步应用：

- **Flutter 客户端**（`lib/`）：UI、状态管理、gRPC 客户端
- **嵌入式 Go 后端**（`server/`）：通过 gomobile 编译进 app，提供 gRPC 控制接口 + HTTP 文件传输
- 手机**直连** SMB / WebDAV / NFS 存储，无数据库、无中间服务器，存储文件系统即数据库（按 `YYYY/MM/DD/` 组织）
- 本仓库为开源版，仅含核心查看与同步功能（SMB/WebDAV/NFS）

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
make server-aar    # → android/app/libs/server.aar

# 3. 运行或构建 app
flutter run                          # debug 模式
make apk                             # release APK
```

> ⚠️ **重要**：`flutter run` / `flutter build apk` 不会自动构建 AAR。如果跳过 `make server-aar`，app 能安装但内嵌 Go server 无法启动（表现为同步功能不可用）。

> Windows 构建：`make server-windows` 需要手动 `sed` + `dlltool` 后处理，建议在 Linux/WSL 下开发。

## 代码结构速览

| 目录 | 内容 | 常见改动场景 |
|------|------|-------------|
| `lib/` | Flutter UI + gRPC 客户端 | 界面、状态、同步逻辑（`lib/sync/`） |
| `server/api/` | gRPC 服务实现 + HTTP 文件处理 | 新增接口 |
| `server/imgmanager/` | 核心：上传/下载/缩略图/加密 | 同步行为改动 |
| `server/drive/` | 存储后端（smb / webdav / nfs） | 新增存储类型 |
| `proto/` | protobuf 定义（唯一数据源） | 新增 RPC 时改这里 |
| `test/` | Docker 测试环境（SMB/WebDAV/NFS 容器） | 集成测试 |

**约定**：
- `lib/proto/*` 与 `proto/*.pb.go` 是**生成代码，不要手改**，改 `proto/img_syncer.proto` 后执行 `make protobuf`
- 存储布局：`YYYY/MM/DD/{timestamp}_{filename}`，缩略图在 `.thumbnail/` 镜像目录，Live Photos 在 `live_<name>/` 子目录
- 状态管理用 `provider` + `ChangeNotifier` 单例（见 `lib/state_model.dart`），导航用 `Navigator.push(MaterialPageRoute(...))`，无路由库

## 如何提交 Issue

请使用 GitHub 自带的 issue 模板（Bug 报告 / 功能建议），并尽量提供：

- 设备型号 + 系统版本 + Pho 版本号
- 存储类型（SMB / WebDAV / NFS）与配置方式
- 复现步骤 + 期望行为 + 实际行为
- 相关截图或错误日志

**提问前**先搜一下已有 issue，避免重复。使用类问题（"怎么用""为什么不自动同步"）请先看 README 的「介绍」与「构建」章节，仍无法解决再开 issue。

## 如何提交 Pull Request

1. **Fork** 本仓库并克隆到本地
2. 创建功能分支：`git checkout -b fix/xxx` 或 `git checkout -b feat/xxx`
3. 做出改动，**自测通过**（见下方「测试」）
4. 提交（提交信息用中文，风格参考现有 `git log`，如 `feat: 支持xxx` / `fix: 修复xxx`）
5. 推送到你的 fork，创建 PR
6. 在 PR 描述中说明：**改了什么、为什么改、如何测试的、是否影响现有同步逻辑**

> PR 尽量小而聚焦：一个 PR 解决一个问题。大改动请先开 issue 讨论方案，避免白做。

## 代码风格

- **Dart**：遵循 `analysis_options.yaml`（`package:flutter_lints`），提交前运行 `flutter analyze` 确认无新增告警
- **Go**：`gofmt` 格式化，遵循现有包结构与命名（`ImgManager`、`StorageDrive` 接口等）
- **注释**：使用中文
- **不要**修改生成代码、不要引入无必要的第三方依赖、不要动与开源版无关的 Pro 功能逻辑

## 测试

```bash
make test   # 需要 Docker：拉起 SMB/WebDAV/NFS 容器 → go test ./server/api ./server/drive
```

- 涉及同步/存储的改动务必跑 `make test`
- 纯 UI 改动至少真机 `flutter run` 自测一遍：配置存储 → 同步几张照片 → 云端浏览
- 目前无 Dart 单元测试，改动简单 UI 时自测即可

## 新手从哪开始？

- 带有 **`good first issue`** 标签的 issue 最适合入门：任务边界清晰、改动范围小，维护者会在 issue 下提供指引
- 常见简单任务类型：
  - **i18n**：新增语言支持（如繁体中文 #76）——只需加 ARB 文件 + 注册
  - **文档**：README 完善、FAQ 补充、注释优化
  - **UI 细节**：间距/配色/交互微调（使用 `lib/design_tokens.dart` 中的设计 token，不要写死数值）
- 不确定怎么做？直接在 issue 下留言，维护者和其他贡献者会协助

## 交流渠道

- GitHub Issues（bug / 功能建议）
- QQ 交流群（使用咨询、闲聊），二维码见 README
