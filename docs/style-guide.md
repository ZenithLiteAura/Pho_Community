# 代码与文案风格规范

> 本文档定义 Pho 的**代码格式、命名、注释、提交信息、错误处理与 UI 文案**规范。
> 目标：**边界清晰、风格一致、可机械校验**。
> 术语保留英文，说明使用中文。

---

## 1. 格式化

**统一使用官方或事实标准的格式化工具，不手工调整格式。**

| 语言 | 工具 | 说明 |
|---|---|---|
| Dart | `dart format` | 行宽 80，遵循 `analysis_options.yaml`（`package:flutter_lints`） |
| Go | `gofmt` | 标准格式，提交前必须执行 |
| Kotlin | `ktlint` | POC 阶段随 `native/` 一并接入 |
| Swift | `swiftformat` | iOS 侧 |

**约定**：

- 格式化是**前置门禁**，不是评审讨论的内容。
- 提交前至少执行：`dart format .`、`gofmt -w .`。
- 禁止在提交中出现大段无意义的空白/换行调整（会淹没真实改动）。

---

## 2. 命名

### 2.1 通则

1. **一律使用英文**。
2. **禁止拼音**（如 `tupian`、`shezhi`）。
3. **禁止中英混搭**（如 `getUser信息`、`同步Timer`）。
4. 通用缩写保持统一：`id`、`url`、`http`、`json`、`ui`、`db`。

### 2.2 分语言规则

| 语言 | 类型 | 规则 | 示例 |
|---|---|---|---|
| Dart | 文件/目录 | `snake_case` | `settings_storage.dart` |
| Dart | 类/枚举 | `UpperCamelCase` | `StorageConfigBody` |
| Dart | 变量/函数 | `lowerCamelCase` | `syncProgress` |
| Dart | 常量 | `lowerCamelCase` 或 `SCREAMING_SNAKE_CASE` | `maxHistory` |
| Go | 文件/包 | `lowercase` / 短单词 | `imgmanager` |
| Go | 导出 | `UpperCamelCase` | `ImgManager` |
| Go | 私有 | `lowerCamelCase` | `genPath` |
| Kotlin | 类 | `UpperCamelCase` | `MiuixSettingsView` |
| Kotlin | 函数/变量 | `lowerCamelCase` | `setKeepScreenOn` |

### 2.3 目录命名

目录用小写英文单词，不用缩写拼接：`storage`、`settings`、`sync`、`notifications`。

---

## 3. 注释

1. **注释使用中文**（与团队语言一致）。
2. **解释「为什么」，而不是「做什么」**——代码本身已说明做什么。
3. 公开 API、非直观算法、平台差异、历史坑点**必须**注释。
4. 注释里的历史结论要**写清结论与原因**，例如：

```dart
// 不用 wakelock_plus：其 Dart 端(platform_interface 1.6.0)与 Android 端(1.1.4)
// 的 pigeon 通道名不一致，调用必定抛 channel-error。
```

5. 禁止保留被注释掉的死代码（用版本控制保留历史）。
6. `TODO` 必须带上下文：`// TODO(模块): 具体待办`。

---

## 4. 提交信息

### 4.1 格式

```
<type>: <中文简述>

<可选：正文，说明为什么>
```

### 4.2 type 取值

| type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `refactor` | 重构（不改变外部行为） |
| `docs` | 文档 |
| `style` | 格式/文案调整 |
| `chore` | 构建、依赖、杂项 |
| `test` | 测试 |

### 4.3 示例

```
fix: 修复 Android keepScreenOn 的 pigeon 通道不匹配

根因：Dart 端与 Android 端监听的通道名不一致…
```

**要求**：一次提交只做一件事；正文优先说明**根因与取舍**，而非罗列改动文件。

---

## 5. 错误处理

### 5.1 统一形态

**错误码（英文）+ 用户可读消息（中文）**。错误码定义见 `bridge-api.md` 第 5 节。

### 5.2 用户可读消息的格式

```
<操作失败原因>，<建议>
```

示例：

| ✅ 推荐 | ❌ 避免 |
|---|---|
| 文件 2.3GB 超过服务端单次上传上限 8.0GB，请压缩或分段后再试 | Error: 413 |
| 上传中断：与内置服务的连接被关闭，请检查网络存储是否可用 | ClientException with SocketException: Broken pipe |
| 地址为空，请先填写主存储地址 | url is empty |

### 5.3 约定

1. **原始异常不直接展示给用户**，但要写入日志（`logger.addError`）。
2. 可恢复异常用 `warning`，中断性问题用 `error`（与 `logger` 分级一致）。
3. 禁止吞异常不记录。

---

## 6. UI 文案

### 6.1 通则

1. **统一中文**（英文文案仅保留在 `app_en.arb` 中作为本地化资源）。
2. **短句**，避免长从句。
3. **动词开头**：`保存`、`测试连接`、`开始采集`。
4. 不堆砌感叹号，不制造焦虑。
5. **不要机翻感**：避免「您可以通过点击按钮来进行保存」这类句式，直接写「点保存」。
6. 术语保留英文：`WebDAV`、`SMB`、`NFS`、`Dock`、`TLS`。

### 6.2 术语对照（保持全项目一致）

| 统一用词 | 不要混用 |
|---|---|
| 存储 | 储存 |
| 地址 | 网络储存类型、URL（面向用户时） |
| 主存储 / 备用存储 | 主/副、Primary/Backup（面向用户时） |
| 同步 | 上传（两者含义不同，勿混） |
| 日志与诊断 | 日志/诊断工具 |

> 注：`README` 中存在「网络储存设置」等历史写法，属待统一项。

### 6.3 面向开发者的文案

日志、内部错误、异常消息可用英文，但**面向用户的提示一律中文**。

---

## 7. 文档规范

1. **中文为主，术语保留英文**。
2. 每篇文档开头给出**一句话定位**与适用范围。
3. 结论优先：先给判断，再给依据。
4. 涉及代码的结论必须**可核对**（给出文件路径与关键标识）。

---

## 8. 现状差距清单（可直接作为待办）

> 以下为**已核实**的现状偏差，属重构步骤 D 的执行清单。

| # | 差距 | 证据 | 目标 |
|---|---|---|---|
| D1 | ~~Channel 命名与包名不一致~~ **已修复** | 三处 Channel 原为 `com.ZenithLiteAura.app.pho/*`，现已统一为 `com.ZenithLiteAura.app.pho/*`（含 iOS 的 BG task identifier） | 统一为 `com.ZenithLiteAura.app.pho/*` |
| D2 | `lib/` 根目录平铺 | 顶层 20 个 `.dart` 文件与 11 个子目录混放 | 按 `app/` / `bridge/` 分层 |
| D3 | `print` 直用 | **14 处** | 一律走 `logger`（含分级），否则采集功能对其无效 |
| D4 | 硬编码英文文案 | 6 处：`'Not implemented'`、`'Author'`、`'Dock ${l10n.appearanceAndTheme}'`、`'OK'` ×3 | 全部改为 `l10n` 中文文案 |
| D5 | 版本号硬编码且过时 | `settings_about.dart` 的 `'Pho - 3.2.2'`；`settings_route.dart` 的 `const version = '1.0.0'` | 从 `pubspec.yaml` 单一来源读取，或集中常量 |
| D6 | 中英混杂的错误消息 | 如 `'Asset local is null, unable to upload'` | 按 5.2 的中文格式改写 |
| D7 | 服务端错误只有字符串 | `core` 层统一 `success + message` | 增加 `error_code` 字段（兼容式新增） |
| D8 | 桥接职责分散 | 启动/探测/重启散落在 `global.dart`、`run_server.dart` | 收敛到 `bridge/` |

---

## 9. 落地节奏

风格统一不追求一次到位，按以下顺序推进，**每步保证可运行**：

1. 接入格式化工具（D1 之外的机械项，先跑 `dart format` + `gofmt`）
2. 清零 D3（`print` → `logger`）与 D4（硬编码文案）
3. 处理 D5、D6（版本来源与错误文案）
4. 随桥接层重构处理 D1、D7、D8
5. 目录分层（D2）在桥接层收敛后执行，避免同时移动文件与改逻辑