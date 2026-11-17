import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:sasatap/core/hex_utils.dart';

/// A domain error raised by the NFC layer.
///
/// Keeping the platform exception out of the UI makes it possible to present
/// actionable guidance for the most common NFC failures.
class NfcException implements Exception {
  const NfcException(this.code, this.message, {this.hint});

  final String code;
  final String message;
  final String? hint;

  @override
  String toString() => message;
}

/// The result of a successful tag poll.
class NfcTagScan {
  NfcTagScan({
    required this.tag,
    required this.records,
    this.ndefReadError,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();

  final NFCTag tag;
  final List<ndef.NDEFRecord> records;
  final String? ndefReadError;
  final DateTime scannedAt;

  String get uid => normalizeUid(tag.id);

  String get formattedUid => formatUid(tag.id);

  bool get isNdefAvailable => tag.ndefAvailable == true;

  bool get isWritable => tag.ndefWritable == true;

  bool get canBeMadeReadOnly => tag.ndefCanMakeReadOnly == true;

  bool get isType2 => tag.type == NFCTagType.mifare_ultralight;

  int? get capacity => tag.ndefCapacity;
}

/// A single readable block/page/sector returned by [NfcService.dumpMemory].
class MemoryPage {
  const MemoryPage({required this.label, required this.bytes});

  final String label;
  final Uint8List bytes;
}

/// A memory dump for tags that expose block-level access.
class MemoryDump {
  const MemoryDump({
    required this.title,
    required this.pages,
    this.truncated = false,
  });

  final String title;
  final List<MemoryPage> pages;

  /// True when a read failed before the end of the addressable memory.
  final bool truncated;

  int get totalBytes =>
      pages.fold(0, (total, page) => total + page.bytes.length);
}

/// Thin, stateful wrapper around `FlutterNfcKit`.
///
/// The service owns the polling session lifecycle so callers cannot leak a
/// CoreNFC session or leave Android reader mode bound to an old tag. All
/// platform errors are translated to [NfcException] values with user-facing
/// hints.
class NfcService {
  bool _sessionOpen = false;
  bool _operationInProgress = false;
  NFCTag? _lastTag;
  NfcTagScan? _lastScan;

  bool get sessionOpen => _sessionOpen;

  NFCTag? get lastTag => _lastTag;

  NfcTagScan? get lastScan => _lastScan;

  bool get busy => _operationInProgress;

  /// Checks hardware availability without starting a session.
  Future<NFCAvailability> checkAvailability() async {
    try {
      return await FlutterNfcKit.nfcAvailability;
    } on MissingPluginException {
      return NFCAvailability.not_supported;
    } on Object catch (error) {
      throw _mapError(error);
    }
  }

  /// Polls for a tag and (when possible) reads its NDEF records.
  ///
  /// The session is intentionally left open so follow-up operations such as
  /// writing, formatting or raw transceiving can use the same tag. Call
  /// [close] when the workflow ends.
  Future<NfcTagScan> scan({
    Duration timeout = const Duration(seconds: 20),
    String alertMessage = 'Hold your phone near the NFC tag',
    bool readRecords = true,
  }) async {
    if (_operationInProgress) {
      throw const NfcException(
        'busy',
        'Another NFC operation is already running.',
        hint: 'Wait for it to finish before starting a new scan.',
      );
    }

    _operationInProgress = true;
    try {
      await _ensureAvailable();

      // A previous screen may have left a session open.
      await close();

      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        iosAlertMessage: alertMessage,
        iosMultipleTagMessage:
            'More than one tag was detected. Leave only one tag near the phone.',
        androidCheckNDEF: true,
      );

      _sessionOpen = true;
      _lastTag = tag;

      var records = <ndef.NDEFRecord>[];
      String? readError;
      if (readRecords && tag.ndefAvailable != false) {
        try {
          records = await FlutterNfcKit.readNDEFRecords(cached: false);
        } on Object catch (error) {
          // Metadata is still useful even when NDEF decoding fails. Surface
          // the decode error alongside the tag details instead of failing the
          // whole scan.
          readError = _mapError(error).message;
        }
      }

      final scan = NfcTagScan(
        tag: tag,
        records: records,
        ndefReadError: readError,
      );
      _lastScan = scan;
      return scan;
    } on Object catch (error) {
      _sessionOpen = false;
      _lastTag = null;
      _lastScan = null;
      await _safeFinish();
      throw _mapError(error);
    } finally {
      _operationInProgress = false;
    }
  }

  /// Reads the NDEF message from the currently connected tag.
  Future<List<ndef.NDEFRecord>> readRecords({bool cached = false}) {
    return _run(() => FlutterNfcKit.readNDEFRecords(cached: cached));
  }

  /// Writes [records] to the connected tag.
  ///
  /// When [maxCapacity] is known, the encoded message is checked before the
  /// platform call to avoid a partial write on small tags.
  Future<void> writeRecords(List<ndef.NDEFRecord> records, {int? maxCapacity}) {
    return _run(() async {
      final tag = _lastTag;
      if (tag?.ndefAvailable != true) {
        throw const NfcException(
          'ndef_unavailable',
          'This tag is not NDEF formatted.',
          hint: 'Format a supported tag before writing an NDEF message.',
        );
      }
      if (tag?.ndefWritable != true) {
        throw const NfcException(
          'not_writable',
          'This tag is not reported as writable.',
          hint: 'The tag may be locked or protected by a password.',
        );
      }
      final size = ndef.encodeNdefMessage(records).length;
      if (maxCapacity != null && maxCapacity > 0 && size > maxCapacity) {
        throw NfcException(
          'message_too_large',
          'The NDEF message is $size bytes but this tag can hold about '
              '$maxCapacity bytes.',
          hint: 'Shorten the payload or use a tag with more capacity.',
        );
      }
      await FlutterNfcKit.writeNDEFRecords(records);
    });
  }

  /// Writes one NDEF record to the connected tag.
  Future<void> writeRecord(ndef.NDEFRecord record, {int? maxCapacity}) {
    return writeRecords(<ndef.NDEFRecord>[record], maxCapacity: maxCapacity);
  }

  /// Writes a single record and always closes the platform session.
  ///
  /// This is used by the instant Wi-Fi onboarding flow. Unlike the
  /// scan-then-write workflow, the whole poll/write/finish lifecycle is owned
  /// here so a read-only tag, timeout or capacity failure cannot leave a
  /// session open.
  Future<NfcTagScan> writeInstantRecord(
    ndef.NDEFRecord record, {
    Duration timeout = const Duration(seconds: 20),
    String alertMessage = 'Hold your phone near the tag to write',
  }) async {
    if (_operationInProgress) {
      throw const NfcException(
        'busy',
        'Another NFC operation is already running.',
        hint: 'Wait for it to finish before starting a new write.',
      );
    }

    _operationInProgress = true;
    var finishMessage = 'Write failed';
    try {
      await _ensureAvailable();
      await close();

      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        iosAlertMessage: alertMessage,
        iosMultipleTagMessage:
            'More than one tag was detected. Leave only one tag near the '
            'phone.',
        androidCheckNDEF: true,
      );
      _sessionOpen = true;
      _lastTag = tag;

      if (tag.ndefWritable != true) {
        throw const NfcException(
          'not_writable',
          'This NFC tag is read-only.',
          hint:
              'Use a writable tag, or remove its lock or password '
              'protection first.',
        );
      }

      final capacity =
          tag.ndefCapacity ??
          (tag.type == NFCTagType.mifare_ultralight
              ? _type2Capacity(tag)
              : null);
      final size = ndef.encodeNdefMessage(<ndef.NDEFRecord>[record]).length;
      if (capacity != null && capacity > 0 && size > capacity) {
        throw NfcException(
          'message_too_large',
          'The Wi-Fi payload is $size bytes, but this tag can hold about '
              '$capacity bytes.',
          hint:
              'Use a larger tag such as NTAG215, or shorten the network name '
              'or password.',
        );
      }

      await FlutterNfcKit.writeNDEFRecords(<ndef.NDEFRecord>[record]);
      final scan = NfcTagScan(tag: tag, records: <ndef.NDEFRecord>[record]);
      _lastScan = scan;
      finishMessage = 'Wi-Fi tag written';
      return scan;
    } on Object catch (error) {
      throw _mapError(error);
    } finally {
      _sessionOpen = false;
      _lastTag = null;
      _lastScan = null;
      try {
        await FlutterNfcKit.finish(iosAlertMessage: finishMessage);
      } on Object {
        // The platform may have already ended a failed polling session.
      }
      _operationInProgress = false;
    }
  }

  /// Locks the NDEF area of the connected tag. This is irreversible.
  Future<void> makeReadOnly(NfcTagScan scan) {
    return _run(() async {
      _ensureCurrentScan(scan);
      if (!scan.isNdefAvailable) {
        throw const NfcException(
          'ndef_unavailable',
          'This tag is not NDEF formatted.',
          hint: 'Only formatted NDEF tags can be made read-only.',
        );
      }
      if (!scan.isWritable || !scan.canBeMadeReadOnly) {
        throw const NfcException(
          'not_lockable',
          'The tag does not report that it can be locked.',
          hint:
              'It may already be read-only or this tag type may not '
              'support permanent locking.',
        );
      }
      await FlutterNfcKit.makeNdefReadOnly();
    });
  }

  /// Sends a raw APDU or technology command and returns the response as hex.
  Future<String> transceiveHex(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _run(() async {
      final compact = command.replaceAll(RegExp(r'\s+'), '');
      if (compact.isEmpty) {
        throw const NfcException(
          'invalid_hex',
          'Enter a command in hexadecimal format.',
          hint: 'Example: 30 04 reads four pages starting at page 4.',
        );
      }
      if (!isValidHex(compact)) {
        throw const NfcException(
          'invalid_hex',
          'The command must contain an even number of hexadecimal digits.',
        );
      }
      final response = await FlutterNfcKit.transceive(
        compact.toUpperCase(),
        timeout: timeout,
      );
      return response.replaceAll(' ', '').toUpperCase();
    });
  }

  /// Formats a blank NFC Type 2 tag (MIFARE Ultralight / NTAG).
  ///
  /// Writes a Type 2 Capability Container and an empty NDEF TLV. This refuses
  /// to touch other tag families because their formatting procedures differ.
  Future<void> formatTag(NfcTagScan scan) {
    return _run(() async {
      _ensureCurrentScan(scan);
      if (!scan.isType2) {
        throw const NfcException(
          'unsupported_tag',
          'Formatting is currently available for NFC Type 2 tags only.',
          hint:
              'Use an NDEF-formatted tag, or a dedicated formatter for '
              'MIFARE Classic, Type 4 or Type 5 tags.',
        );
      }
      if (scan.isNdefAvailable && !scan.isWritable) {
        throw const NfcException(
          'not_writable',
          'This Type 2 tag is not reported as writable.',
          hint: 'Formatting would fail on a locked or protected tag.',
        );
      }

      final capacity = _type2Capacity(scan.tag);
      final rawSizeByte = capacity ~/ 8;
      final sizeByte = rawSizeByte < 0x06
          ? 0x06
          : (rawSizeByte > 0xFF ? 0xFF : rawSizeByte);

      // Capability Container: magic E1, version 1.0, data size / 8, free.
      await _writeType2Page(3, <int>[0xE1, 0x10, sizeByte, 0x00]);
      // Empty NDEF TLV: type 0x03, length 0x00, terminator 0xFE.
      await _writeType2Page(4, <int>[0x03, 0x00, 0xFE, 0x00]);

      final verify = await _readType2Pages(3);
      if (verify[0] != 0xE1) {
        throw const NfcException(
          'format_failed',
          'The tag did not accept the Capability Container write.',
          hint: 'The tag may be locked or its configuration may be read-only.',
        );
      }
    });
  }

  /// Erases the NDEF message while leaving the tag formatted.
  Future<void> eraseTag(NfcTagScan scan) {
    return _run(() async {
      _ensureCurrentScan(scan);
      if (scan.isNdefAvailable && !scan.isWritable) {
        throw const NfcException(
          'not_writable',
          'This tag is not reported as writable.',
          hint: 'The tag may be locked or protected by a password.',
        );
      }
      if (!scan.isNdefAvailable) {
        if (!scan.isType2) {
          throw const NfcException(
            'ndef_unavailable',
            'This tag is not NDEF formatted.',
            hint: 'Format a supported Type 2 tag before erasing its message.',
          );
        }
        await _writeType2Page(4, <int>[0x03, 0x00, 0xFE, 0x00]);
        return;
      }
      try {
        await FlutterNfcKit.writeNDEFRecords(const <ndef.NDEFRecord>[]);
      } on Object {
        if (!scan.isType2) {
          rethrow;
        }
        // Some Type 2 implementations reject a zero-record NDEF message.
        // Reset the NDEF TLV directly instead.
        await _writeType2Page(4, <int>[0x03, 0x00, 0xFE, 0x00]);
      }
    });
  }

  /// Reads blocks, pages or sectors from the connected tag.
  Future<MemoryDump> dumpMemory(NfcTagScan scan) {
    return _run(() async {
      if (scan.isType2) {
        return _dumpType2(scan);
      }
      if (scan.tag.type == NFCTagType.iso15693) {
        return _dumpIso15693(scan);
      }
      if (scan.tag.type == NFCTagType.mifare_classic && Platform.isAndroid) {
        return _dumpMifareClassic(scan);
      }
      throw const NfcException(
        'unsupported_tag',
        'Block-level memory dumping is not supported for this tag type.',
        hint:
            'Type 2 (NTAG / MIFARE Ultralight), ISO 15693 and MIFARE '
            'Classic tags on Android are supported.',
      );
    });
  }

  /// Verifies a NTAG21x password without changing configuration.
  Future<String> authenticatePassword(String password) {
    return _run(() async {
      final passwordBytes = _fixedHex(password, 4, 'Password');
      final response = await _transceiveBytes(<int>[0x1B, ...passwordBytes]);
      if (response.length < 2) {
        throw const NfcException(
          'authentication_failed',
          'The tag rejected the password.',
          hint: 'Check the 4-byte hexadecimal password and try again.',
        );
      }
      return bytesToHex(response.sublist(0, 2));
    });
  }

  /// Enables NTAG21x password protection for write access.
  ///
  /// This writes PWD, PACK, AUTH0 and the PROT bit in the configuration pages.
  /// It is intentionally limited to NTAG213/215/216 geometry because writing
  /// configuration pages on other tag families can permanently brick them.
  Future<void> setPassword(
    NfcTagScan scan, {
    required String password,
    String pack = '0000',
    int firstProtectedPage = 4,
  }) {
    return _run(() async {
      final geometry = _ntagConfigGeometry(scan.tag);
      if (geometry == null) {
        throw const NfcException(
          'unsupported_tag',
          'Password protection is supported for NTAG213/215/216 tags only.',
        );
      }
      if (firstProtectedPage < 0 || firstProtectedPage > 0xFF) {
        throw const NfcException(
          'invalid_input',
          'The first protected page must be between 0 and 255.',
        );
      }

      final passwordBytes = _fixedHex(password, 4, 'Password');
      final packBytes = _fixedHex(pack, 2, 'PACK');
      final config = await _readType2Pages(geometry.configPage);

      // Layout: CFG0, CFG1, PWD, PACK (four consecutive pages).
      final cfg0 = Uint8List.fromList(config.sublist(0, 4));
      final cfg1 = Uint8List.fromList(config.sublist(4, 8));

      if ((cfg1[0] & 0x40) != 0) {
        throw const NfcException(
          'config_locked',
          'The tag configuration is locked and cannot be changed.',
        );
      }

      cfg0[3] = firstProtectedPage;
      cfg1[0] = cfg1[0] | 0x80; // PROT: protect writes from AUTH0 onwards.

      await _writeType2Page(geometry.passwordPage, passwordBytes);
      await _writeType2Page(geometry.packPage, <int>[...packBytes, 0x00, 0x00]);
      await _writeType2Page(geometry.configPage, cfg0);
      // Writing CFG1 last enables protection immediately; no more writes are
      // possible without authenticating.
      await _writeType2Page(geometry.configPage + 1, cfg1);
    });
  }

  /// Removes NTAG21x password protection after authenticating with the current
  /// password.
  Future<void> removePassword(NfcTagScan scan, {required String password}) {
    return _run(() async {
      final geometry = _ntagConfigGeometry(scan.tag);
      if (geometry == null) {
        throw const NfcException(
          'unsupported_tag',
          'Password removal is supported for NTAG213/215/216 tags only.',
        );
      }

      final passwordBytes = _fixedHex(password, 4, 'Password');
      final authResponse = await _transceiveBytes(<int>[
        0x1B,
        ...passwordBytes,
      ]);
      if (authResponse.length < 2) {
        throw const NfcException(
          'authentication_failed',
          'The tag rejected the password.',
          hint: 'The password is required before protection can be removed.',
        );
      }

      final config = await _readType2Pages(geometry.configPage);
      final cfg0 = Uint8List.fromList(config.sublist(0, 4));
      final cfg1 = Uint8List.fromList(config.sublist(4, 8));
      cfg0[3] = 0xFF; // AUTH0 = no protected pages.
      cfg1[0] = cfg1[0] & ~0x80; // Clear PROT.

      await _writeType2Page(geometry.configPage, cfg0);
      await _writeType2Page(geometry.configPage + 1, cfg1);
    });
  }

  /// Closes the active session. Safe to call when no session is open.
  Future<void> close({String? iosAlertMessage}) async {
    if (!_sessionOpen) {
      return;
    }
    _sessionOpen = false;
    _lastTag = null;
    _lastScan = null;
    await _safeFinish(iosAlertMessage: iosAlertMessage);
  }

  void _ensureCurrentScan(NfcTagScan scan) {
    final tag = _lastTag;
    if (!_sessionOpen ||
        tag == null ||
        scan.uid.isEmpty ||
        normalizeUid(tag.id) != scan.uid) {
      throw const NfcException(
        'tag_session_mismatch',
        'This operation does not match the currently connected tag.',
        hint: 'Scan the tag again and keep it against the phone.',
      );
    }
  }

  /// Releases any platform session when the service is no longer used.
  Future<void> shutdown() => close();

  Future<void> _ensureAvailable() async {
    final availability = await checkAvailability();
    switch (availability) {
      case NFCAvailability.available:
        return;
      case NFCAvailability.disabled:
        throw const NfcException(
          'nfc_disabled',
          'NFC is turned off on this device.',
          hint: 'Enable NFC in your device settings, then try again.',
        );
      case NFCAvailability.not_supported:
        throw const NfcException(
          'nfc_unsupported',
          'This device does not support NFC.',
          hint: 'NFC requires compatible Android or iPhone hardware.',
        );
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    if (_operationInProgress) {
      throw const NfcException(
        'busy',
        'Another NFC operation is already running.',
        hint: 'Wait for the current operation to finish.',
      );
    }
    if (!_sessionOpen) {
      throw const NfcException(
        'no_session',
        'No NFC tag is connected.',
        hint: 'Scan a tag first and keep it against the phone.',
      );
    }

    _operationInProgress = true;
    try {
      return await action();
    } on Object catch (error) {
      throw _mapError(error);
    } finally {
      _operationInProgress = false;
    }
  }

  Future<MemoryDump> _dumpType2(NfcTagScan scan) async {
    final reportedPages = scan.tag.mifareInfo?.blockCount ?? 0;
    final pageLimit = reportedPages > 0
        ? reportedPages
        : _type2Capacity(scan.tag) ~/ 4 + 4;
    final pages = <MemoryPage>[];
    var truncated = false;

    for (var page = 0; page < pageLimit && page < 256; page += 4) {
      try {
        final data = await _readType2Pages(page);
        for (var offset = 0; offset < 4; offset++) {
          final pageNumber = page + offset;
          if (pageNumber >= pageLimit) {
            break;
          }
          pages.add(
            MemoryPage(
              label: 'Page $pageNumber',
              bytes: Uint8List.fromList(
                data.sublist(offset * 4, (offset * 4) + 4),
              ),
            ),
          );
        }
      } on Object {
        if (pages.isEmpty) {
          rethrow;
        }
        truncated = true;
        break;
      }
    }

    return MemoryDump(
      title: 'NFC Type 2 memory',
      pages: pages,
      truncated: truncated,
    );
  }

  Future<MemoryDump> _dumpIso15693(NfcTagScan scan) async {
    final pages = <MemoryPage>[];
    final blockCount = scan.tag.mifareInfo?.blockCount ?? 0;
    final limit = blockCount > 0 ? blockCount : 32;
    var truncated = false;

    for (var block = 0; block < limit && block < 512; block++) {
      try {
        final data = await FlutterNfcKit.readBlock(block);
        pages.add(MemoryPage(label: 'Block $block', bytes: data));
      } on Object {
        if (pages.isEmpty) {
          rethrow;
        }
        truncated = true;
        break;
      }
    }

    return MemoryDump(
      title: 'ISO 15693 memory',
      pages: pages,
      truncated: truncated,
    );
  }

  Future<MemoryDump> _dumpMifareClassic(NfcTagScan scan) async {
    final pages = <MemoryPage>[];
    final sectorCount = scan.tag.mifareInfo?.sectorCount ?? 16;
    var truncated = false;

    for (var sector = 0; sector < sectorCount; sector++) {
      try {
        final data = await FlutterNfcKit.readSector(sector);
        pages.add(MemoryPage(label: 'Sector $sector', bytes: data));
      } on Object {
        if (pages.isEmpty) {
          rethrow;
        }
        truncated = true;
        break;
      }
    }

    return MemoryDump(
      title: 'MIFARE Classic memory',
      pages: pages,
      truncated: truncated,
    );
  }

  Future<Uint8List> _readType2Pages(int page) async {
    final response = await _transceiveBytes(<int>[0x30, page & 0xFF]);
    if (response.length < 16) {
      throw const NfcException(
        'short_read',
        'The tag returned an incomplete page read.',
        hint: 'Keep the tag still and try again.',
      );
    }
    return Uint8List.fromList(response.sublist(0, 16));
  }

  Future<void> _writeType2Page(int page, List<int> value) async {
    if (value.length > 4) {
      throw const NfcException(
        'invalid_input',
        'A Type 2 page write can contain at most 4 bytes.',
      );
    }
    final padded = <int>[...value, ...List<int>.filled(4 - value.length, 0)];
    final response = await _transceiveBytes(<int>[
      0xA2,
      page & 0xFF,
      ...padded,
    ]);
    if (response.isNotEmpty && !response.contains(0x0A)) {
      throw const NfcException(
        'write_failed',
        'The tag rejected the page write.',
        hint: 'The page may be locked or protected by a password.',
      );
    }
  }

  Future<Uint8List> _transceiveBytes(List<int> command) async {
    final response = await FlutterNfcKit.transceive(
      Uint8List.fromList(command),
      timeout: const Duration(seconds: 5),
    );
    return _stripStatusWord(response);
  }

  static Uint8List _stripStatusWord(Uint8List data) {
    if (data.length >= 2 &&
        data[data.length - 2] == 0x90 &&
        data[data.length - 1] == 0x00) {
      return Uint8List.fromList(data.sublist(0, data.length - 2));
    }
    return data;
  }

  static int _type2Capacity(NFCTag tag) {
    final pages = tag.mifareInfo?.blockCount;
    switch (pages) {
      case 16:
        return 48;
      case 20:
        return 64;
      case 45:
        return 144;
      case 135:
        return 504;
      case 231:
        return 888;
    }
    final capacity = tag.ndefCapacity;
    if (capacity != null && capacity > 0) {
      return capacity;
    }
    return 144;
  }

  static _NtagConfigGeometry? _ntagConfigGeometry(NFCTag tag) {
    final pages = tag.mifareInfo?.blockCount;
    switch (pages) {
      case 45:
        return const _NtagConfigGeometry(
          configPage: 41,
          passwordPage: 43,
          packPage: 44,
        );
      case 135:
        return const _NtagConfigGeometry(
          configPage: 131,
          passwordPage: 133,
          packPage: 134,
        );
      case 231:
        return const _NtagConfigGeometry(
          configPage: 227,
          passwordPage: 229,
          packPage: 230,
        );
    }

    // Only tags whose geometry exactly matches a known NTAG21x layout are
    // eligible. Guessing from capacity could write configuration pages on a
    // different tag family and permanently damage it.
    return null;
  }

  static Uint8List _fixedHex(String value, int bytes, String label) {
    final cleaned = value.replaceAll(RegExp('[^0-9a-fA-F]'), '');
    if (cleaned.length != bytes * 2) {
      throw NfcException(
        'invalid_hex',
        '$label must be exactly ${bytes * 2} hexadecimal digits.',
      );
    }
    return hexToBytes(cleaned);
  }

  Future<void> _safeFinish({String? iosAlertMessage}) async {
    try {
      await FlutterNfcKit.finish(iosAlertMessage: iosAlertMessage);
    } on Object {
      // Finishing a session that the platform already invalidated is safe to
      // ignore.
    }
  }

  NfcException _mapError(Object error) {
    if (error is NfcException) {
      return error;
    }
    if (error is MissingPluginException) {
      return const NfcException(
        'nfc_unsupported',
        'NFC is not available in this build.',
        hint: 'Run SasaTap on a physical Android or iOS device.',
      );
    }
    if (error is TimeoutException) {
      return const NfcException(
        'timeout',
        'The NFC operation timed out.',
        hint: 'Keep the tag still against the phone and try again.',
      );
    }
    if (error is FormatException) {
      return NfcException('invalid_input', error.message.toString());
    }
    if (error is PlatformException) {
      switch (error.code) {
        case '400':
          return NfcException(
            'bad_request',
            error.message ?? 'The tag rejected the command.',
            hint: 'Check the NDEF payload or raw command and try again.',
          );
        case '404':
          return const NfcException(
            'tag_not_found',
            'No NFC tag was found.',
            hint: 'Hold the tag against the NFC antenna and try again.',
          );
        case '405':
          return const NfcException(
            'not_writable',
            'This tag is not writable.',
            hint: 'It may be locked, read-only, or protected by a password.',
          );
        case '408':
          return const NfcException(
            'timeout',
            'The NFC operation timed out.',
            hint: 'Keep the tag still and close to the phone.',
          );
        case '409':
          return const NfcException(
            'session_canceled',
            'The NFC session was canceled.',
            hint: 'Bring the tag close to the phone before the session ends.',
          );
        case '410':
          return const NfcException(
            'tag_lost',
            'The tag moved away from the phone.',
            hint:
                'Keep the tag against the phone until the operation finishes.',
          );
      }
      return NfcException(
        error.code,
        error.message ?? 'The NFC operation failed.',
      );
    }
    return NfcException('nfc_error', error.toString());
  }
}

class _NtagConfigGeometry {
  const _NtagConfigGeometry({
    required this.configPage,
    required this.passwordPage,
    required this.packPage,
  });

  final int configPage;
  final int passwordPage;
  final int packPage;
}
