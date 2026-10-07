import 'package:flutter/material.dart';
import 'package:img_syncer/app/state/event_bus.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:img_syncer/bridge/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/miuix_dropdown.dart';
import 'package:img_syncer/app/state/webdav_config_store.dart';
import 'package:img_syncer/app/widgets/motion/miuix_overlay.dart';

/// WebDAV 配置表单（多配置版）。
///
/// 与旧版的区别：
///  - 旧版固定「主存储 + 备份存储」两槽位，备份作为主目标写失败后的**自动回退**目标；
///  - 本版改为**多具名配置**（配置1、配置2…），顶部下拉选择当前使用哪一条，
///    并支持新建 / 重命名 / 删除。**不再有自动回退**：同时只使用选中的那一条。
///
/// 生效时机：切换下拉只换「编辑对象」，真正写入并应用到 Go 服务端是在点「保存」时
/// ——避免"选到尚未填写的配置就把存储置空"。
class WebDavForm extends StatefulWidget {
  const WebDavForm({Key? key}) : super(key: key);

  @override
  WebDavFormState createState() => WebDavFormState();
}

class WebDavFormState extends State<WebDavForm> {
  final GlobalKey _formKey = GlobalKey<FormState>();

  List<WebdavConfig> _configs = <WebdavConfig>[];
  String? _activeId;
  bool _loading = true;

  TextEditingController? urlController;
  TextEditingController? usernameController;
  TextEditingController? passwordController;
  TextEditingController? rootPathController;

  /// 测试结果仅作反馈，不作为保存按钮的启用条件。
  bool testPassed = false;
  String? errormsg;
  String currentPath = "";
  bool insecure = true;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
    rootPathController = TextEditingController();
    _loadConfigs();
  }

  @override
  void dispose() {
    urlController?.dispose();
    usernameController?.dispose();
    passwordController?.dispose();
    rootPathController?.dispose();
    super.dispose();
  }

  // ── 载入 ────────────────────────────────────────────────

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    var list = await WebdavConfigStore.load(prefs);

    // 列表为空（用户删空过，或首次安装且旧键皆空）：补一个空「配置1」。
    if (list.isEmpty) {
      list = <WebdavConfig>[
        WebdavConfigStore.createConfig('${l10n.configNamePrefix}1'),
      ];
      await WebdavConfigStore.save(list, prefs);
    }

    var activeId = await WebdavConfigStore.loadActiveId(prefs);
    final active = WebdavConfigStore.activeOf(list, activeId);
    activeId = active?.id;
    await WebdavConfigStore.saveActiveId(activeId, prefs);

    if (!mounted) return;
    setState(() {
      _configs = list;
      _activeId = activeId;
      _fillFields(active);
      _loading = false;
    });
  }

  /// 把某条配置填进输入框。
  void _fillFields(WebdavConfig? c) {
    urlController!.text = c?.url ?? '';
    usernameController!.text = c?.username ?? '';
    passwordController!.text = c?.password ?? '';
    rootPathController!.text = c?.rootPath ?? '';
    insecure = c?.insecure ?? true;
    testPassed = false;
    errormsg = null;
  }

  /// 当前生效（正在编辑）的配置。
  WebdavConfig? get _activeConfig {
    if (_configs.isEmpty) return null;
    for (final c in _configs) {
      if (c.id == _activeId) return c;
    }
    return _configs.first;
  }

  // ── 配置管理 ────────────────────────────────────────────

  Future<void> _selectConfig(String? id) async {
    if (id == null || id == _activeId) return;
    final prefs = await SharedPreferences.getInstance();
    await WebdavConfigStore.saveActiveId(id, prefs);
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _fillFields(_activeConfig);
    });
  }

  Future<void> _newConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final name = WebdavConfigStore.nextDefaultName(
      _configs,
      l10n.configNamePrefix,
    );
    final created = WebdavConfigStore.createConfig(name);
    final list = <WebdavConfig>[..._configs, created];
    await WebdavConfigStore.save(list, prefs);
    await WebdavConfigStore.saveActiveId(created.id, prefs);
    if (!mounted) return;
    setState(() {
      _configs = list;
      _activeId = created.id;
      _fillFields(created);
    });
  }

  Future<void> _renameConfig() async {
    final target = _activeConfig;
    if (target == null) return;
    final controller = TextEditingController(text: target.name);
    final newName = await showMiuixDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameConfig),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.configName),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null) return;
    if (newName.isEmpty) {
      SnackBarManager.showSnackBar(l10n.configNameEmpty);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    target.name = newName;
    await WebdavConfigStore.save(_configs, prefs);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteConfig() async {
    final target = _activeConfig;
    if (target == null) return;
    final confirmed = await showMiuixDialog<bool>(
      context: context,
      // 破坏性操作：不允许下拉关闭
      dragToDismiss: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfig),
        content: Text(l10n.deleteConfigConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteConfig),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final list = _configs.where((c) => c.id != target.id).toList();
    // 允许删到空：列表为空时不选中任何配置，下次进入会自动补「配置1」。
    final next = _activeId == target.id
        ? (list.isNotEmpty ? list.first.id : null)
        : _activeId;
    await WebdavConfigStore.save(list, prefs);
    await WebdavConfigStore.saveActiveId(next, prefs);
    if (!mounted) return;
    setState(() {
      _configs = list;
      _activeId = next;
      _fillFields(WebdavConfigStore.activeOf(list, next));
    });
  }

  // ── 连接测试 / 保存 ─────────────────────────────────────

  Future<bool> checkWebdav() async {
    final url = urlController!.text;
    final username = usernameController!.text;
    final password = passwordController!.text;
    if (url.isEmpty) {
      return false;
    }
    try {
      final rsp2 = await storage.cli.setDriveWebdav(SetDriveWebdavRequest(
          addr: url, username: username, password: password,
          insecure: insecure));
      if (!rsp2.success) {
        setState(() {
          errormsg = rsp2.message;
        });
        print("setDriveWebdav failed: ${rsp2.message}");
        return false;
      }
      final rsp3 =
          await storage.cli.listDriveWebdavDir(ListDriveWebdavDirRequest());
      if (!rsp3.success) {
        setState(() {
          errormsg = rsp3.message;
        });
        print("listDriveWebdavDir failed: ${rsp3.message}");
        return false;
      }
    } catch (e) {
      setState(() {
        errormsg = e.toString();
      });
      print("checkWebdav failed: $e");
    }
    return true;
  }

  Future<List<String>> getRootPath(String dir) async {
    final rsp = await storage.cli
        .listDriveWebdavDir(ListDriveWebdavDirRequest(dir: dir));
    if (!rsp.success) {
      setState(() {
        errormsg = rsp.message;
      });
      return [];
    }
    return rsp.dirs;
  }

  /// 测试当前输入框里的这条配置。
  Future<void> testCurrentStorage() async {
    final url = urlController!.text;
    if (url.isEmpty) {
      setState(() => errormsg = l10n.configNotReady);
      showErrorDialog(errormsg!);
      return;
    }
    try {
      final rsp = await storage.cli.setDriveWebdav(SetDriveWebdavRequest(
        addr: url,
        username: usernameController!.text,
        password: passwordController!.text,
        root: rootPathController!.text,
        insecure: insecure,
      ));
      if (rsp.success) {
        setState(() {
          testPassed = true;
          errormsg = null;
        });
        SnackBarManager.showSnackBar(l10n.testSuccess);
      } else {
        setState(() {
          testPassed = false;
          errormsg = rsp.message;
        });
        showErrorDialog(rsp.message);
      }
    } catch (e) {
      setState(() {
        testPassed = false;
        errormsg = e.toString();
      });
      showErrorDialog(e.toString());
    }
  }

  /// 保存当前配置并把「选中的这条」应用到 Go 服务端（单目标，无自动回退）。
  Future<void> saveCurrentConfig() async {
    final target = _activeConfig;
    if (target == null) return;

    final prefs = await SharedPreferences.getInstance();

    // 1) 字段写回该配置并持久化
    target.url = urlController!.text.trim();
    target.username = usernameController!.text;
    target.password = passwordController!.text;
    target.rootPath = rootPathController!.text.trim();
    target.insecure = insecure;
    await WebdavConfigStore.save(_configs, prefs);
    await WebdavConfigStore.saveActiveId(target.id, prefs);

    // 2) 未填写完整：只保存不应用，并如实反映"当前无可用存储"
    if (!target.isUsable) {
      settingModel.setRemoteStorageSetted(false);
      if (!mounted) return;
      setState(() {});
      SnackBarManager.showSnackBar(l10n.configNotReady);
      return;
    }

    // 3) 应用到服务端
    try {
      final rsp = await storage.cli.setDriveWebdav(SetDriveWebdavRequest(
        addr: target.url,
        username: target.username,
        password: target.password,
        root: target.rootPath,
        insecure: target.insecure,
      ));
      if (rsp.success) {
        await prefs.setString('drive', driveName[Drive.webDav]!);
        settingModel.setRemoteStorageSetted(true);
        assetModel.remoteLastError = null;
        eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
        SnackBarManager.showSnackBar(l10n.configSaved);
      } else {
        settingModel.setRemoteStorageSetted(false);
        assetModel.remoteLastError = rsp.message;
        showErrorDialog(rsp.message);
      }
    } catch (e) {
      settingModel.setRemoteStorageSetted(false);
      assetModel.remoteLastError = e.toString();
      showErrorDialog(e.toString());
    }
    if (!mounted) return;
    setState(() {});
  }

  // ── UI ─────────────────────────────────────────────────

  Widget input(String label, TextEditingController? c) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLarge,
          vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: c,
        obscureText: false,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  /// 配置选择行：下拉 + 新建 / 重命名 / 删除。
  Widget configSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.paddingLarge, AppSpacing.paddingSmall,
          AppSpacing.paddingLarge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiuixDropdownField<String>(
            label: l10n.activeConfig,
            value: _activeId ?? '',
            enabled: _configs.isNotEmpty,
            items: [
              for (var i = 0; i < _configs.length; i++)
                MiuixDropdownItem<String>(
                  value: _configs[i].id,
                  // 名称留空时按位置显示「配置N」（与新建配置的默认命名一致）
                  label: _configs[i].name.trim().isEmpty
                      ? '${l10n.configNamePrefix}${i + 1}'
                      : _configs[i].name,
                ),
            ],
            onChanged: (id) => _selectConfig(id),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                onPressed: _newConfig,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.newConfig),
              ),
              TextButton.icon(
                onPressed: _activeConfig == null ? null : _renameConfig,
                icon: const Icon(Icons.drive_file_rename_outline, size: 18),
                label: Text(l10n.renameConfig),
              ),
              TextButton.icon(
                onPressed: _activeConfig == null ? null : _deleteConfig,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.deleteConfig),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 一组「测试连接 + 保存」按钮。
  Widget actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLarge,
          vertical: AppSpacing.paddingSmall),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton.tonal(
                onPressed: testCurrentStorage,
                child: Text(l10n.testStorage,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: saveCurrentConfig,
                child: Text(l10n.save,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final children = <Widget>[];
    children.add(configSelector());

    if (_configs.isEmpty) {
      children.add(Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingLarge, AppSpacing.md,
            AppSpacing.paddingLarge, AppSpacing.paddingSmall),
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.noConfigYet,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ));
      return Form(key: _formKey, child: Column(children: children));
    }

    // ── 当前配置的字段 ──
    children.add(Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLarge,
          vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: urlController,
        obscureText: false,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: "URL",
          helperText: "eg: https://your.domain:port",
        ),
      ),
    ));
    children.add(
        input('${l10n.username} (${l10n.optional})', usernameController));
    children.add(
        input('${l10n.password} (${l10n.optional})', passwordController));
    children.add(CheckboxListTile(
      title: Text(l10n.skipTLS),
      subtitle: insecure
          ? Text('⚠️ ${l10n.allowUntrusted}',
              style: TextStyle(color: Theme.of(context).colorScheme.error))
          : null,
      value: insecure,
      onChanged: (v) {
        setState(() => insecure = v!);
      },
    ));
    children.add(Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLarge,
          vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: rootPathController,
        obscureText: false,
        enableInteractiveSelection: true,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: l10n.rootPath,
          helperText: "eg: /path/photo",
          suffixIcon: IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              checkWebdav().then((available) {
                if (!mounted) return;
                if (!available) {
                  showErrorDialog(errormsg!);
                } else {
                  showMiuixDialog(
                    context: context,
                    builder: (BuildContext context) => rootPathDialog(),
                  );
                }
              });
            },
          ),
        ),
      ),
    ));
    children.add(actionButtons());

    return Form(
      key: _formKey,
      child: Column(children: children),
    );
  }

  Widget rootPathDialog() {
    currentPath = "/";
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          child: SizedBox(
            height: 500,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Text(
                    l10n.selectRoot,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "${l10n.currentPath}: $currentPath",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Divider(
                  indent: 20,
                  endIndent: 20,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                FutureBuilder(
                  future: getRootPath(currentPath),
                  builder: (context, AsyncSnapshot<List<String>> snapshot) {
                    if (snapshot.hasData) {
                      return Expanded(
                        child: ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            return InkWell(
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(25, 0, 25, 0),
                                height: 35,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  snapshot.data![index],
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              onTap: () {
                                setDialogState(() {
                                  if (currentPath == "") {
                                    currentPath = snapshot.data![index];
                                  } else {
                                    currentPath =
                                        "$currentPath${snapshot.data![index]}/";
                                  }
                                });
                              },
                            );
                          },
                        ),
                      );
                    } else {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                  child: Divider(
                    indent: 20,
                    endIndent: 20,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                      width: 120,
                      height: 55,
                      child: OutlinedButton(
                        child: Text(l10n.cancel),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                      width: 120,
                      height: 55,
                      child: FilledButton(
                        child: Text(l10n.save),
                        onPressed: () {
                          rootPathController!.text = currentPath;
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showErrorDialog(String msg) {
    showMiuixDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.connectFailed),
        content: Text(msg),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}