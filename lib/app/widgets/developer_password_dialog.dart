import 'package:flutter/material.dart';

import 'package:img_syncer/app/state/developer_mode.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 弹出开发者密码框；校验通过返回 true。
Future<bool> showDeveloperPasswordDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const DeveloperPasswordDialog(),
  );
  return ok ?? false;
}

/// 开发者密码输入框。
///
/// 只做 MD5 摘要比对（[verifyDeveloperPassword]），明文既不进源码也不进仓库。
class DeveloperPasswordDialog extends StatefulWidget {
  const DeveloperPasswordDialog({Key? key}) : super(key: key);

  @override
  State<DeveloperPasswordDialog> createState() =>
      _DeveloperPasswordDialogState();
}

class _DeveloperPasswordDialogState extends State<DeveloperPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (verifyDeveloperPassword(_controller.text)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = AppLocalizations.of(context)!.devPasswordWrong);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.devPasswordTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscure,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: l10n.devPasswordHint,
          errorText: _error,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.devPasswordConfirm),
        ),
      ],
    );
  }
}
