import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sasatap/core/nfc_service.dart';

/// Owns the advanced tag-tool operations shown in the Other tab.
class OtherProvider extends ChangeNotifier {
  OtherProvider(this._nfc);

  final NfcService _nfc;

  NfcTagScan? _scan;
  bool _busy = false;
  NfcException? _error;
  String? _message;
  MemoryDump? _dump;
  String? _transceiveOutput;

  NfcTagScan? get scan => _scan;

  bool get busy => _busy;

  NfcException? get error => _error;

  String? get message => _message;

  MemoryDump? get dump => _dump;

  String? get transceiveOutput => _transceiveOutput;

  Future<void> scanTag() async {
    if (_busy) {
      return;
    }
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();

    try {
      _scan = await _nfc.scan(
        alertMessage: 'Hold your phone near the tag',
      );
      _dump = null;
      _transceiveOutput = null;
    } on NfcException catch (error) {
      _error = error;
      _scan = null;
    } on Object catch (error) {
      _error = NfcException('unexpected', error.toString());
      _scan = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> format() => _execute(
    'Tag formatted as NDEF.',
    () => _nfc.formatTag(_requireScan()),
  );

  Future<void> erase() => _execute(
    'NDEF message erased.',
    () => _nfc.eraseTag(_requireScan()),
  );

  Future<void> makeReadOnly() => _execute(
    'Tag locked. It can no longer be written.',
    () => _nfc.makeReadOnly(_requireScan()),
  );

  Future<void> setPassword({
    required String password,
    required String pack,
    int firstProtectedPage = 4,
  }) {
    return _execute(
      'Password protection enabled.',
      () => _nfc.setPassword(
        _requireScan(),
        password: password,
        pack: pack,
        firstProtectedPage: firstProtectedPage,
      ),
    );
  }

  Future<void> removePassword(String password) => _execute(
    'Password protection removed.',
    () => _nfc.removePassword(_requireScan(), password: password),
  );

  Future<void> dumpMemory() => _execute(
    'Memory dump complete.',
    () async {
      _dump = await _nfc.dumpMemory(_requireScan());
    },
  );

  Future<void> transceive(String command) => _execute(
    'Command sent.',
    () async {
      _transceiveOutput = await _nfc.transceiveHex(command);
    },
  );

  void clearFeedback() {
    _error = null;
    _message = null;
    notifyListeners();
  }

  Future<void> closeSession() async {
    await _nfc.close(iosAlertMessage: 'Session closed');
    _scan = null;
    _dump = null;
    _transceiveOutput = null;
    notifyListeners();
  }

  NfcTagScan _requireScan() {
    final scan = _scan;
    if (scan == null) {
      throw const NfcException(
        'no_session',
        'Scan a tag first.',
        hint: 'The tag must stay connected while an operation runs.',
      );
    }
    return scan;
  }

  Future<void> _execute(
    String successMessage,
    Future<void> Function() action,
  ) async {
    if (_busy) {
      return;
    }
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();

    try {
      await action();
      _message = successMessage;
    } on NfcException catch (error) {
      _error = error;
    } on Object catch (error) {
      _error = NfcException('unexpected', error.toString());
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_nfc.close());
    super.dispose();
  }
}
