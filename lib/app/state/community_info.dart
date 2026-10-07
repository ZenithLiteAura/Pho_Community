/// 社区发行版元信息（单一事实来源）。
///
/// 这里同时被「启动版权弹窗」与「设置 → 关于」使用，
/// 避免像过去那样把版本号/作者名硬编码散落在多个页面里。
/// 发版时只需同步修改本文件与 pubspec.yaml。
library;

/// 发行版显示名。
///
/// 必须与 `android/app/src/main/AndroidManifest.xml` 的 `android:label`、
/// iOS/macOS 的 `CFBundleDisplayName` 保持一致。
const String communityAppName = 'Pho 社区版';

/// 发行版版本号（与 pubspec.yaml 的 `version` 保持同步）。
const String communityVersion = '3.4.4';

/// 原作者。
const String originalAuthor = 'fregie';

/// 原作者仓库地址（弹窗与关于页展示、外开）。
const String originalAuthorRepo = 'https://github.com/fregie/pho';

/// 本社区发行版的维护者。
const String communityMaintainer = 'ZenithLiteAura';

/// 本社区发行版仓库地址。
const String communityRepo = 'https://github.com/ZenithLiteAura/Pho_Community';

/// 许可证名称与地址。
const String licenseName = 'GNU General Public License v3.0';
const String licenseUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';

/// 本社区发行版对原作品做出修改的日期。
///
/// GPL-3.0 第 5(a) 条要求修改版显著标注「已修改」及日期，
/// 启动弹窗与关于页都会展示该日期。
const String communityModifiedDate = '2026-10-07';

/// 「关闭启动前弹窗」的持久化 key。
///
/// `false`（默认）表示每次启动都显示版权弹窗；
/// 用户可在「设置 → 关于 → 高级设置」里改为 `true` 关闭。
const String startupNoticePrefKey = 'startup_notice_disabled';
