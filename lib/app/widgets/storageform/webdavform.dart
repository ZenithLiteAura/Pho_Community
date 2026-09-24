import 'package:flutter/material.dart';
import 'package:img_syncer/app/state/event_bus.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:img_syncer/bridge/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';

class WebDavForm extends StatefulWidget {
  const WebDavForm({Key? key}) : super(key: key);

  @override
  WebDavFormState createState() => WebDavFormState();
}

class WebDavFormState extends State<WebDavForm> {
  @protected
  final GlobalKey _formKey = GlobalKey<FormState>();
  TextEditingController? urlController;
  TextEditingController? usernameController;
  TextEditingController? passwordController;
  TextEditingController? rootPathController;
  TextEditingController? backupUrlController;
  TextEditingController? backupUsernameController;
  TextEditingController? backupPasswordController;
  TextEditingController? backupRootPathController;
  /// 主 / 备用存储各自的测试结果。
  ///
  /// 仅用于给出反馈，**不再**作为保存按钮的启用条件 ——
  /// 原先必须先测试成功才能保存，导致「保存按钮点不动」。
  bool primaryTestPassed = false;
  bool backupTestPassed = false;
  String? errormsg;
  String currentPath = "";
  bool insecure = false;
  bool backupInsecure = true;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
    rootPathController = TextEditingController();
    backupUrlController = TextEditingController();
    backupUsernameController = TextEditingController();
    backupPasswordController = TextEditingController();
    backupRootPathController = TextEditingController();
    SharedPreferences.getInstance().then((prefs) {
      urlController!.text = prefs.getString('webdav_url') ?? "";
      usernameController!.text = prefs.getString('webdav_username') ?? "";
      passwordController!.text = prefs.getString('webdav_password') ?? "";
      rootPathController!.text = prefs.getString('webdav_root_path') ?? "";
      backupUrlController!.text = prefs.getString('webdav_url2') ?? "";
      backupUsernameController!.text = prefs.getString('webdav_username2') ?? "";
      backupPasswordController!.text = prefs.getString('webdav_password2') ?? "";
      backupRootPathController!.text = prefs.getString('webdav_root_path2') ?? "";
      setState(() {
        insecure = prefs.getBool('webdav_insecure') ?? true;
        backupInsecure = prefs.getBool('webdav_insecure2') ?? true;
      });
    });
  }

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

  Widget input(
      String label, TextEditingController? c, void Function(String?)? onSaved) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: c,
        obscureText: false,
        onSaved: onSaved,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  /// 测试**主存储**连接。
  ///
  /// 成功/失败只作为反馈（弹提示或错误框），不影响保存按钮的可用性。
  /// 注意：该调用同时会把主存储设为当前 drive（与原有行为一致）。
  Future<void> testPrimaryStorage() async {
    final url = urlController!.text;
    if (url.isEmpty) {
      setState(() => errormsg = '请先填写主存储地址');
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
          primaryTestPassed = true;
          errormsg = null;
        });
        SnackBarManager.showSnackBar(l10n.testSuccess);
      } else {
        setState(() {
          primaryTestPassed = false;
          errormsg = rsp.message;
        });
        showErrorDialog(rsp.message);
      }
    } catch (e) {
      setState(() {
        primaryTestPassed = false;
        errormsg = e.toString();
      });
      showErrorDialog(e.toString());
    }
  }

  /// 测试**备用存储**连接。
  ///
  /// 原先只能随主存储被连带测试，无法单独验证备用目标是否可用。
  Future<void> testBackupStorage() async {
    final backupUrl = backupUrlController!.text;
    if (backupUrl.isEmpty) {
      setState(() => errormsg = l10n.backupUrlEmpty);
      showErrorDialog(errormsg!);
      return;
    }
    try {
      final rsp = await storage.cli.setDriveWebdav(SetDriveWebdavRequest(
        addr: backupUrl,
        username: backupUsernameController!.text,
        password: backupPasswordController!.text,
        root: backupRootPathController!.text,
        insecure: backupInsecure,
      ));
      if (rsp.success) {
        setState(() {
          backupTestPassed = true;
          errormsg = null;
        });
        SnackBarManager.showSnackBar(l10n.testSuccess);
      } else {
        setState(() {
          backupTestPassed = false;
          errormsg = rsp.message;
        });
        showErrorDialog(rsp.message);
      }
    } catch (e) {
      setState(() {
        backupTestPassed = false;
        errormsg = e.toString();
      });
      showErrorDialog(e.toString());
    }
  }

  /// 一组「测试 + 保存」按钮。主存储与备用存储各自独立一组。
  Widget actionButtons({
    required Future<void> Function() onTest,
    required Future<void> Function() onSave,
    required String testLabel,
    required String saveLabel,
  }) {
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
                onPressed: () => onTest(),
                child: Text(testLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                // 保存不再依赖「是否测试成功」：原先 testSuccess 未通过时
                // 按钮为 null（禁用），表现为「保存按钮点不动」。
                onPressed: () => onSave(),
                child: Text(saveLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 保存**主存储**配置（只写主存储字段与 drive，不动备用字段）。
  Future<void> savePrimary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', urlController!.text);
    await prefs.setString('webdav_username', usernameController!.text);
    await prefs.setString('webdav_password', passwordController!.text);
    await prefs.setString('webdav_root_path', rootPathController!.text);
    await prefs.setBool('webdav_insecure', insecure);
    await prefs.setString('drive', driveName[Drive.webDav]!);
    settingModel.setRemoteStorageSetted(true);
    assetModel.remoteLastError = null;
    eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
    // 不再 pop：本表单同时嵌在设置树的「存储与备份」页里，
    // pop 会让用户无法继续填写另一项（主 / 备用）。
    SnackBarManager.showSnackBar(l10n.savePrimaryStorage);
  }

  /// 保存**备用存储**配置（只写备用字段；地址清空即表示取消备用）。
  Future<void> saveBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url2', backupUrlController!.text);
    await prefs.setString('webdav_username2', backupUsernameController!.text);
    await prefs.setString('webdav_password2', backupPasswordController!.text);
    await prefs.setString('webdav_root_path2', backupRootPathController!.text);
    await prefs.setBool('webdav_insecure2', backupInsecure);
    eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
    SnackBarManager.showSnackBar(l10n.saveBackupStorage);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
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
        input('${l10n.username} (${l10n.optional})', usernameController, null));
    children.add(
        input('${l10n.password} (${l10n.optional})', passwordController, null));
    children.add(CheckboxListTile(
      title: const Text('跳过 TLS 证书验证'),
      subtitle: insecure
          ? Text('⚠️ 跳过验证有安全风险',
              style: TextStyle(color: Theme.of(context).colorScheme.error))
          : null,
      value: insecure,
      onChanged: (v) async {
        setState(() => insecure = v!);
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('webdav_insecure', v!);
      },
    ));
    children.add(Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
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
                if (!available) {
                  showErrorDialog(errormsg!);
                } else {
                  showDialog(
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
    // 主存储的「测试 + 保存」独立成组
    children.add(actionButtons(
      onTest: testPrimaryStorage,
      onSave: savePrimary,
      testLabel: l10n.testPrimaryStorage,
      saveLabel: l10n.savePrimaryStorage,
    ));
    // 备份存储（可选）：双 WebDAV 目标，主目标失败自动回退备份
    children.add(Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.paddingLarge, AppSpacing.md, AppSpacing.paddingLarge, 0),
      alignment: Alignment.centerLeft,
      child: Text(
        l10n.backupStorage,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    ));
    children.add(Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.paddingLarge, 4, AppSpacing.paddingLarge, 0),
      alignment: Alignment.centerLeft,
      child: Text(
        l10n.backupStorageDesc,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ));
    children.add(Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: backupUrlController,
        obscureText: false,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: "Backup URL",
          helperText: "eg: https://your.domain:port",
        ),
      ),
    ));
    children.add(input('${l10n.username} (${l10n.optional})', backupUsernameController, null));
    children.add(input('${l10n.password} (${l10n.optional})', backupPasswordController, null));
    children.add(CheckboxListTile(
      title: const Text('跳过 TLS 证书验证（备份）'),
      value: backupInsecure,
      onChanged: (v) async {
        setState(() => backupInsecure = v!);
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('webdav_insecure2', v!);
      },
    ));
    children.add(Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: backupRootPathController,
        obscureText: false,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Backup root path',
          helperText: "eg: /path/photo",
        ),
      ),
    ));
    // 备用存储的「测试 + 保存」独立成组
    children.add(actionButtons(
      onTest: testBackupStorage,
      onSave: saveBackup,
      testLabel: l10n.testBackupStorage,
      saveLabel: l10n.saveBackupStorage,
    ));
    return Form(
      key: _formKey,
      child: Column(
        children: children,
      ),
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
                                  style: Theme.of(context).textTheme.bodyMedium,
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
    showDialog<String>(
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
