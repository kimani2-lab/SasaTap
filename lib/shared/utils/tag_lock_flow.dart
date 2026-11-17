import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';

class _LockRequest {
  const _LockRequest({
    required this.password,
    required this.pack,
    required this.firstProtectedPage,
  });

  final String password;
  final String pack;
  final int firstProtectedPage;
}

/// Locks the tag identified by [expectedUid] with NTAG password protection.
///
/// The tag is scanned again because the write/read session has already ended.
/// Returns true when protection was enabled successfully.
Future<bool> showLockTagFlow(
  BuildContext context, {
  required String expectedUid,
}) async {
  final request = await showDialog<_LockRequest>(
    context: context,
    builder: (context) => const _LockTagDialog(),
  );
  if (request == null || !context.mounted) {
    return false;
  }

  final nfc = context.read<NfcService>();
  try {
    final scan = await nfc.scan(
      alertMessage: 'Hold the tag near the phone to lock it',
    );
    if (scan.formattedUid.toLowerCase() != expectedUid.toLowerCase()) {
      await nfc.close(iosAlertMessage: 'Different tag');
      if (context.mounted) {
        showAppSnackBar(
          context,
          'That tag does not match the saved tag '
          '(${scan.formattedUid}).',
          isError: true,
        );
      }
      return false;
    }

    await nfc.setPassword(
      scan,
      password: request.password,
      pack: request.pack,
      firstProtectedPage: request.firstProtectedPage,
    );
    await nfc.close(iosAlertMessage: 'Tag locked');
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Password protection enabled. Keep the password and PACK safe.',
      );
    }
    return true;
  } on NfcException catch (error) {
    await nfc.close(iosAlertMessage: 'Lock failed');
    if (context.mounted) {
      await showErrorDialog(context, error);
    }
    return false;
  } on Object catch (error) {
    await nfc.close(iosAlertMessage: 'Lock failed');
    if (context.mounted) {
      showAppSnackBar(context, 'Could not lock the tag: $error', isError: true);
    }
    return false;
  }
}

class _LockTagDialog extends StatefulWidget {
  const _LockTagDialog();

  @override
  State<_LockTagDialog> createState() => _LockTagDialogState();
}

class _LockTagDialogState extends State<_LockTagDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _pack = TextEditingController(text: '0000');
  final _firstPage = TextEditingController(text: '4');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _password.dispose();
    _pack.dispose();
    _firstPage.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final firstPage = int.tryParse(_firstPage.text.trim());
    if (firstPage == null) {
      return;
    }
    Navigator.of(context).pop(
      _LockRequest(
        password: _cleanHex(_password.text),
        pack: _cleanHex(_pack.text),
        firstProtectedPage: firstPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: const Text('Lock with password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This enables NTAG password protection. The tag can still be '
                'read, but it cannot be rewritten without the password.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F ]')),
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: '4 bytes as 8 hex digits, e.g. A1B2C3D4',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (_cleanHex(value ?? '').length != 8) {
                    return 'Enter exactly 8 hexadecimal digits.';
                  }
                  return null;
                },
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: const Text('Advanced protection settings'),
                children: [
                  TextFormField(
                    controller: _pack,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F ]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'PACK',
                      helperText: '2 bytes, e.g. 1234',
                    ),
                    validator: (value) {
                      if (_cleanHex(value ?? '').length != 4) {
                        return 'Enter exactly 4 hexadecimal digits.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstPage,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'First protected page',
                      helperText: 'Usually 4',
                    ),
                    validator: (value) {
                      final page = int.tryParse((value ?? '').trim());
                      if (page == null || page < 0 || page > 255) {
                        return 'Enter a page between 0 and 255.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Store the password and PACK safely. Losing them can leave the '
                'tag permanently unwritable.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lock tag')),
      ],
    );
  }

  static String _cleanHex(String value) =>
      value.replaceAll(RegExp('[^0-9a-fA-F]'), '').toUpperCase();
}
