import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/settings/settings_data_management.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 二级页：存储与备份 —— 主 WebDAV 配置 + 备份存储配置 + 数据管理入口。
class SettingsStoragePage extends StatefulWidget {
  const SettingsStoragePage({Key? key}) : super(key: key);

  @override
  State<SettingsStoragePage> createState() => _SettingsStoragePageState();
}

class _SettingsStoragePageState extends State<SettingsStoragePage> {
  // ── 主 WebDAV 配置 ──
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _rootCtrl = TextEditingController();
  bool _insecure = true;

  // ── 备份 WebDAV 配置 ──
  final _bakUrlCtrl = TextEditingController();
  final _bakUserCtrl = TextEditingController();
  final _bakPassCtrl = TextEditingController();
  final _bakRootCtrl = TextEditingController();
  bool _bakInsecure = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _urlCtrl.text = p.getString('webdav_url') ?? '';
        _userCtrl.text = p.getString('webdav_username') ?? '';
        _passCtrl.text = p.getString('webdav_password') ?? '';
        _rootCtrl.text = p.getString('webdav_root_path') ?? '';
        _bakUrlCtrl.text = p.getString('webdav_url2') ?? '';
        _bakUserCtrl.text = p.getString('webdav_username2') ?? '';
        _bakPassCtrl.text = p.getString('webdav_password2') ?? '';
        _bakRootCtrl.text = p.getString('webdav_root_path2') ?? '';
        _insecure = p.getBool('webdav_insecure') ?? true;
        _bakInsecure = p.getBool('webdav_insecure2') ?? true;
      });
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _rootCtrl.dispose();
    _bakUrlCtrl.dispose();
    _bakUserCtrl.dispose();
    _bakPassCtrl.dispose();
    _bakRootCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageAndBackup)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // ── 主 WebDAV 配置 ──
          _sectionHeader(context, l10n.primaryStorage),
          Card(
            child: Column(
              children: [
                _inputField(context, l10n.remoteStorageType, _urlCtrl, 'https://nas.local:5006'),
                _inputField(context, l10n.username, _userCtrl, 'admin'),
                _inputField(context, l10n.password, _passCtrl, '••••••••', obscure: true),
                _toggleRow(
                  context,
                  icon: Icons.gpp_bad,
                  iconBg: AppColors.accentWarning.withAlpha(26),
                  iconColor: AppColors.accentWarning,
                  title: l10n.skipTLS,
                  subtitle: _insecure ? '⚠ ${l10n.allowUntrusted}' : '',
                  value: _insecure,
                  onChanged: (v) => setState(() => _insecure = v),
                ),
                _inputField(context, l10n.rootPath, _rootCtrl, '/path/photo'),
                _buildActionButtons(onTest: _testPrimary),
              ],
            ),
          ),
          // ── 备份 WebDAV 配置 ──
          _sectionHeader(context, l10n.backupStorage),
          Card(
            child: Column(
              children: [
                _inputField(context, l10n.backupUrl, _bakUrlCtrl, 'https://backup.local:5006'),
                _inputField(context, '${l10n.username} (${l10n.optional})', _bakUserCtrl, ''),
                _inputField(context, '${l10n.password} (${l10n.optional})', _bakPassCtrl, '••••••••', obscure: true),
                _toggleRow(
                  context,
                  icon: Icons.gpp_bad,
                  iconBg: AppColors.accentWarning.withAlpha(26),
                  iconColor: AppColors.accentWarning,
                  title: l10n.skipTLS,
                  value: _bakInsecure,
                  onChanged: (v) => setState(() => _bakInsecure = v),
                ),
                _inputField(context, l10n.backupRootPath, _bakRootCtrl, '/path/photo'),
                _buildActionButtons(onTest: _testBackup),
              ],
            ),
          ),
          // ── 数据管理 ──
          _sectionHeader(context, l10n.dataManagement),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_zip_outlined, size: 26),
              title: Text(l10n.dataManagement),
              subtitle: Text(
                l10n.backupRestore,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsDataManagementPage(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── UI helpers ──

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              letterSpacing: 0.05,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _inputField(BuildContext context, String label, TextEditingController ctrl, String hint, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: ctrl, obscureText: obscure, decoration: InputDecoration(hintText: hint)),
        ],
      ),
    );
  }

  Widget _toggleRow(BuildContext context, {required IconData icon, required Color iconBg, required Color iconColor, required String title, String subtitle = '', required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      secondary: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  /// v3.0 统一主/备存储的底部按钮组：测试连接 + 保存，并排布局。
  /// [onTest] 由调用方决定是测主存储还是测备份存储（拆分自原合并的测试逻辑）。
  Widget _buildActionButtons({required VoidCallback onTest}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.wifi_find, size: 20),
                label: Text(l10n.testStorage),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _save,
                child: Text(l10n.save),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 业务逻辑 ──

  Future<void> _testPrimary() async {
    try {
      final primary = SetDriveWebdavRequest(
        addr: _urlCtrl.text, username: _userCtrl.text,
        password: _passCtrl.text, root: _rootCtrl.text, insecure: _insecure,
      );
      final hasBak = _bakUrlCtrl.text.isNotEmpty;
      final rsp = hasBak
          ? await storage.cli.setDriveWebdavDual(SetDriveWebdavDualRequest(
              primary: primary,
              backup: SetDriveWebdavRequest(
                addr: _bakUrlCtrl.text, username: _bakUserCtrl.text,
                password: _bakPassCtrl.text, root: _bakRootCtrl.text,
                insecure: _bakInsecure,
              ),
            ))
          : await storage.cli.setDriveWebdav(primary);
      if (rsp.success) {
        SnackBarManager.showSnackBar(l10n.testSuccess);
      } else {
        SnackBarManager.showSnackBar(rsp.message);
      }
    } catch (e) {
      SnackBarManager.showSnackBar('Error: $e');
    }
  }

  /// v3.0 新增：仅测试备份存储。备份 URL 为空时直接提示。
  Future<void> _testBackup() async {
    if (_bakUrlCtrl.text.isEmpty) {
      SnackBarManager.showSnackBar(l10n.backupUrlEmpty);
      return;
    }
    try {
      final backup = SetDriveWebdavRequest(
        addr: _bakUrlCtrl.text, username: _bakUserCtrl.text,
        password: _bakPassCtrl.text, root: _bakRootCtrl.text,
        insecure: _bakInsecure,
      );
      final rsp = await storage.cli.setDriveWebdav(backup);
      if (rsp.success) {
        SnackBarManager.showSnackBar(l10n.testSuccess);
      } else {
        SnackBarManager.showSnackBar(rsp.message);
      }
    } catch (e) {
      SnackBarManager.showSnackBar('Error: $e');
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('webdav_url', _urlCtrl.text);
    await p.setString('webdav_username', _userCtrl.text);
    await p.setString('webdav_password', _passCtrl.text);
    await p.setString('webdav_root_path', _rootCtrl.text);
    await p.setBool('webdav_insecure', _insecure);
    await p.setString('webdav_url2', _bakUrlCtrl.text);
    await p.setString('webdav_username2', _bakUserCtrl.text);
    await p.setString('webdav_password2', _bakPassCtrl.text);
    await p.setString('webdav_root_path2', _bakRootCtrl.text);
    await p.setBool('webdav_insecure2', _bakInsecure);
    await p.setString('drive', 'WebDAV');
    settingModel.setRemoteStorageSetted(true);
    eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
    SnackBarManager.showSnackBar(l10n.save);
  }
}
