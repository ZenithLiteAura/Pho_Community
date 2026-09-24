import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/logger/log_collector.dart';

/// 二级页：日志与诊断。
///
/// 用途：遇到问题时开启采集 → 复现问题 → 导出这段日志。
/// 采集只记录**点击「开始采集」之后**产生的日志，停止时自动落盘，
/// 并只保留最近 [LogCollector.maxHistory] 条历史。
class SettingsLogCollectorPage extends StatefulWidget {
  const SettingsLogCollectorPage({Key? key}) : super(key: key);

  @override
  State<SettingsLogCollectorPage> createState() =>
      _SettingsLogCollectorPageState();
}

class _SettingsLogCollectorPageState extends State<SettingsLogCollectorPage> {
  final LogCollector _collector = LogCollector.instance;
  final ScrollController _previewController = ScrollController();

  /// 预览区最多渲染条数，避免超长列表拖慢页面。
  static const int _previewLimit = 200;

  @override
  void initState() {
    super.initState();
    if (!_collector.historyLoaded) {
      _collector.refreshHistory();
    }
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.logAndDiagnostics)),
      body: ListenableBuilder(
        listenable: _collector,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            _buildControlCard(context),
            _buildLevelCard(context),
            _buildPreviewCard(context),
            _buildExportCard(context),
            _buildHistoryCard(context),
          ],
        ),
      ),
    );
  }

  // ── 采集控制 ─────────────────────────────────────────────

  Widget _buildControlCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final collecting = _collector.collecting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  collecting
                      ? Icons.fiber_manual_record
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: collecting ? AppColors.error : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  collecting ? l10n.logCollecting : l10n.logIdle,
                  style: textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${_collector.entryCount} ${l10n.logEntries}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: collecting ? _stopCollecting : _startCollecting,
                icon: Icon(
                    collecting ? Icons.save_alt : Icons.play_circle_outline,
                    size: 20),
                label: Text(
                    collecting ? l10n.logStopCollect : l10n.logStartCollect),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.logDesc,
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── 级别选择 ─────────────────────────────────────────────

  Widget _buildLevelCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.filter_alt_outlined, size: 26),
            title: Text(l10n.logLevel),
            subtitle: Text(
              '${_collector.level.label} ${l10n.logLevelHint}',
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            // 用 Wrap + ChoiceChip 而非 SegmentedButton：
            // 四档标签（WARNING/ERROR）在窄屏上会被压缩甚至溢出。
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: LogLevel.values.map((level) {
                final selected = _collector.level == level;
                return ChoiceChip(
                  label: Text(level.label),
                  selected: selected,
                  onSelected: (_) => _collector.setLevel(level),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 实时预览 ─────────────────────────────────────────────

  Widget _buildPreviewCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = _collector.entries;
    final shown = entries.length > _previewLimit
        ? entries.sublist(entries.length - _previewLimit)
        : entries;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined, size: 26),
            title: Text(l10n.logPreview),
            trailing: Text(
              '${entries.length} ${l10n.logEntries}',
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: Text(
                l10n.logPreviewEmpty,
                style:
                    textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            Container(
              height: 240,
              margin: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Scrollbar(
                controller: _previewController,
                child: ListView.builder(
                  controller: _previewController,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final e = shown[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        e.format(),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: _levelColor(cs, e.level),
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _levelColor(ColorScheme cs, LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return AppColors.error;
      case LogLevel.warning:
        return cs.onSurface;
      case LogLevel.info:
        return cs.onSurface;
      case LogLevel.debug:
        return cs.onSurfaceVariant;
    }
  }

  // ── 导出 ────────────────────────────────────────────────

  Widget _buildExportCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasData = _collector.entryCount > 0;

    return Card(
      child: ListTile(
        enabled: hasData,
        leading: const Icon(Icons.ios_share, size: 26),
        title: Text(l10n.logExport),
        subtitle: Text(
          hasData
              ? '${_collector.entryCount} ${l10n.logEntries}'
              : l10n.logPreviewEmpty,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: hasData ? _exportCurrent : null,
      ),
    );
  }

  // ── 历史记录 ─────────────────────────────────────────────

  Widget _buildHistoryCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final history = _collector.history;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.history, size: 26),
            title: Text(l10n.logHistory),
            subtitle: Text(
              '${l10n.logHistoryKeep} ${LogCollector.maxHistory}',
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: history.isEmpty
                ? null
                : TextButton(
                    onPressed: _clearHistory,
                    child: Text(l10n.logClearHistory),
                  ),
          ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: Text(
                l10n.logHistoryEmpty,
                style:
                    textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            ...history.map(
              (meta) => ListTile(
                dense: true,
                leading: const Icon(Icons.description_outlined, size: 20),
                title: Text(
                  formatTimestamp(meta.startedAt),
                  style: textTheme.bodyMedium,
                ),
                subtitle: Text(
                  meta.readableSize,
                  style: textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.logExport,
                      icon: const Icon(Icons.ios_share, size: 18),
                      onPressed: () => _exportSession(meta),
                    ),
                    IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _collector.deleteSession(meta.path),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 行为 ────────────────────────────────────────────────

  void _startCollecting() {
    _collector.start();
  }

  Future<void> _stopCollecting() async {
    final path = await _collector.stop();
    if (!mounted) return;
    SnackBarManager.showSnackBar(
      path == null ? l10n.logSaveFailed : '${l10n.logExportSuccess}: $path',
    );
  }

  Future<void> _exportCurrent() async {
    await _exportText(
      _collector.buildExportText(),
      _collector.suggestFileName(),
    );
  }

  Future<void> _exportSession(LogSessionMeta meta) async {
    final text = await _collector.readSession(meta.path);
    if (text == null) {
      SnackBarManager.showSnackBar(l10n.logExportFailed);
      return;
    }
    await _exportText(text, meta.fileName);
  }

  Future<void> _exportText(String text, String fileName) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.logExport,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (path != null) {
        SnackBarManager.showSnackBar('${l10n.logExportSuccess}: $path');
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarManager.showSnackBar('${l10n.logExportFailed}: $e');
    }
  }

  Future<void> _clearHistory() async {
    await _collector.clearHistory();
  }
}