import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:sasatap/core/ndef_builder.dart';
import 'package:sasatap/core/nfc_service.dart';

/// Outcome of a write-and-verify operation.
class WriteResult {
  const WriteResult({
    required this.scan,
    required this.bytesWritten,
    required this.verified,
    this.verifyError,
  });

  final NfcTagScan scan;
  final int bytesWritten;
  final bool verified;
  final String? verifyError;
}

/// Owns the write workflow, including capacity checks and read-back
/// verification.
class WriteProvider extends ChangeNotifier {
  WriteProvider(this._nfc);

  final NfcService _nfc;

  bool _writing = false;
  WriteResult? _result;
  NfcException? _error;
  String _status = '';

  bool get writing => _writing;

  WriteResult? get result => _result;

  NfcException? get error => _error;

  String get status => _status;

  Future<void> write(List<ndef.NDEFRecord> records) async {
    if (_writing) {
      return;
    }

    _writing = true;
    _error = null;
    _result = null;
    _status = 'Waiting for a tag…';
    notifyListeners();

    try {
      final scan = await _nfc.scan(
        alertMessage: 'Hold your phone near the tag to write',
      );

      if (!scan.isNdefAvailable) {
        throw const NfcException(
          'ndef_unavailable',
          'This tag is not NDEF formatted.',
          hint: 'Open the Other tab to format a supported Type 2 tag first.',
        );
      }

      final capacity = scan.capacity;
      final size = NdefBuilder.encodedSize(records);
      if (capacity != null && capacity > 0 && size > capacity) {
        throw NfcException(
          'message_too_large',
          'The message is $size bytes but this tag can hold about $capacity '
              'bytes.',
          hint: 'Shorten the payload or use a larger tag.',
        );
      }

      _status = 'Writing NDEF message…';
      notifyListeners();
      await _nfc.writeRecords(records, maxCapacity: capacity);

      _status = 'Verifying the write…';
      notifyListeners();
      var verified = false;
      String? verifyError;
      var storedRecords = records;
      try {
        final readBack = await _nfc.readRecords();
        storedRecords = readBack;
        verified = _recordsMatch(records, readBack);
        if (!verified) {
          verifyError =
              'The tag returned a different NDEF message after writing.';
        }
      } on NfcException catch (error) {
        verifyError = error.message;
      }

      // Keep the read-back records so saving this result stores what is
      // actually on the tag rather than the message from before the write.
      _result = WriteResult(
        scan: NfcTagScan(
          tag: scan.tag,
          records: storedRecords,
          scannedAt: scan.scannedAt,
        ),
        bytesWritten: size,
        verified: verified,
        verifyError: verifyError,
      );
      _status = 'Write complete';
      await _nfc.close(
        iosAlertMessage: verified ? 'Write complete' : 'Write finished',
      );
    } on NfcException catch (error) {
      _error = error;
      _status = '';
      await _nfc.close(iosAlertMessage: 'Write failed');
    } on Object catch (error) {
      _error = NfcException('unexpected', error.toString());
      _status = '';
      await _nfc.close(iosAlertMessage: 'Write failed');
    } finally {
      _writing = false;
      notifyListeners();
    }
  }

  void clear() {
    _result = null;
    _error = null;
    _status = '';
    notifyListeners();
  }

  static bool _recordsMatch(
    List<ndef.NDEFRecord> expected,
    List<ndef.NDEFRecord> actual,
  ) {
    if (expected.length != actual.length) {
      return false;
    }
    for (var index = 0; index < expected.length; index++) {
      if (!expected[index].isEqual(actual[index])) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    unawaited(_nfc.close());
    super.dispose();
  }
}
