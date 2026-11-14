import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef/ndef.dart' as ndef;
import 'package:sasatap/core/hex_utils.dart';

/// A UI-friendly representation of a decoded NDEF record.
class NdefRecordView {
  const NdefRecordView({
    required this.index,
    required this.kind,
    required this.type,
    required this.summary,
    required this.rawHex,
    required this.payloadSize,
    this.details = const <String, String>{},
  });

  final int index;
  final String kind;
  final String type;
  final String summary;
  final String rawHex;
  final int payloadSize;
  final Map<String, String> details;
}

/// Decodes NDEF records into displayable metadata without losing the raw bytes.
class NdefInspector {
  const NdefInspector._();

  static List<NdefRecordView> inspect(List<ndef.NDEFRecord> records) {
    return List<NdefRecordView>.generate(
      records.length,
      (index) => _inspectRecord(index, records[index]),
      growable: false,
    );
  }

  static NdefRecordView _inspectRecord(int index, ndef.NDEFRecord record) {
    final payload = record.payload ?? Uint8List(0);
    final type = record.decodedType ?? _fallbackType(record);
    final rawHex = bytesToHex(record.encode());

    if (record is ndef.UriRecord) {
      return NdefRecordView(
        index: index,
        kind: 'URI',
        type: 'Well-known URI',
        summary: _safe(() => record.uriString ?? '(empty URI)'),
        rawHex: rawHex,
        payloadSize: payload.length,
        details: <String, String>{
          'URI': _safe(() => record.uriString ?? '(empty)'),
          'Prefix': _safe(() => record.prefix ?? '(none)'),
          'Content': _safe(() => record.content ?? '(empty)'),
          'TNF': record.tnf.name,
        },
      );
    }

    if (record is ndef.TextRecord) {
      final text = record.text ?? '';
      return NdefRecordView(
        index: index,
        kind: 'Text',
        type: 'Well-known text',
        summary: _truncate(text, 140),
        rawHex: rawHex,
        payloadSize: payload.length,
        details: <String, String>{
          'Text': text,
          'Language': record.language ?? '(unspecified)',
          'Encoding': record.encodingString,
          'TNF': record.tnf.name,
        },
      );
    }

    if (record is ndef.MimeRecord) {
      final mediaType = record.decodedType ?? 'application/octet-stream';
      if (mediaType == 'application/vnd.wfa.wsc' ||
          mediaType == 'application/vnd.wfa.wsc.1') {
        return _inspectWifiRecord(index, record, mediaType, rawHex);
      }
      if (mediaType == 'text/vcard' ||
          mediaType == 'text/x-vcard' ||
          mediaType == 'text/directory') {
        final text = _decodeText(payload);
        return NdefRecordView(
          index: index,
          kind: 'vCard',
          type: mediaType,
          summary:
              'vCard contact (${payload.length} bytes)',
          rawHex: rawHex,
          payloadSize: payload.length,
          details: <String, String>{
            'MIME type': mediaType,
            'Preview': _truncate(text ?? '(binary payload)', 400),
            'TNF': record.tnf.name,
          },
        );
      }
      if (mediaType.startsWith('text/') ||
          mediaType == 'application/json' ||
          mediaType == 'application/xml') {
        final text = _decodeText(payload) ?? '(unable to decode text)';
        return NdefRecordView(
          index: index,
          kind: 'MIME',
          type: mediaType,
          summary: _truncate(text, 140),
          rawHex: rawHex,
          payloadSize: payload.length,
          details: <String, String>{
            'MIME type': mediaType,
            'Text': text,
            'TNF': record.tnf.name,
          },
        );
      }
      return NdefRecordView(
        index: index,
        kind: 'MIME',
        type: mediaType,
        summary: '${payload.length} bytes of binary data',
        rawHex: rawHex,
        payloadSize: payload.length,
        details: <String, String>{
          'MIME type': mediaType,
          'Payload size': '${payload.length} bytes',
          'TNF': record.tnf.name,
        },
      );
    }

    final text = _decodeText(payload);
    return NdefRecordView(
      index: index,
      kind: record.tnf == ndef.TypeNameFormat.empty ? 'Empty' : 'NDEF',
      type: type.isEmpty ? '(unknown type)' : type,
      summary: text == null
          ? '${payload.length} bytes of binary data'
          : _truncate(text, 140),
      rawHex: rawHex,
      payloadSize: payload.length,
      details: <String, String>{
        'TNF': record.tnf.name,
        'Type': type.isEmpty ? '(empty)' : type,
        'ID': record.idString,
        'Payload size': '${payload.length} bytes',
        if (text != null) 'Text preview': _truncate(text, 400),
      },
    );
  }

  static NdefRecordView _inspectWifiRecord(
    int index,
    ndef.MimeRecord record,
    String mediaType,
    String rawHex,
  ) {
    final payload = record.payload ?? Uint8List(0);
    final details = <String, String>{'MIME type': mediaType};
    var summary = 'Wi-Fi configuration';

    try {
      final credential = _findTlv(payload, 0x100E) ?? payload;
      final attributes = _parseTlvs(credential);
      final ssid = _decodeText(attributes[0x1045]);
      final authentication = _readUint16(attributes[0x1003]);
      final encryption = _readUint16(attributes[0x100F]);
      final hasNetworkKey = attributes.containsKey(0x1027);

      if (ssid != null && ssid.isNotEmpty) {
        summary = 'Wi-Fi network: $ssid';
        details['SSID'] = ssid;
      }
      details['Authentication'] =
          _authenticationLabel(authentication);
      details['Encryption'] = _encryptionLabel(encryption);
      details['Password protected'] = hasNetworkKey ? 'Yes' : 'No';
      if (hasNetworkKey) {
        details['Network key'] = '•••••••• (masked)';
      }
    } on FormatException {
      details['Payload'] = 'Malformed Wi-Fi Simple Configuration data';
    }

    details['TNF'] = record.tnf.name;
    details['Payload size'] = '${payload.length} bytes';
    return NdefRecordView(
      index: index,
      kind: 'Wi-Fi',
      type: mediaType,
      summary: summary,
      rawHex: rawHex,
      payloadSize: payload.length,
      details: details,
    );
  }

  static String _fallbackType(ndef.NDEFRecord record) {
    final type = record.type;
    if (type == null || type.isEmpty) {
      return '';
    }
    final decoded = _decodeText(type);
    if (decoded != null && decoded.trim().isNotEmpty) {
      return decoded;
    }
    return bytesToHex(type, spaced: false);
  }

  static String? _decodeText(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    try {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      final printable = decoded.runes.where((rune) {
        return rune == 0x09 ||
            rune == 0x0A ||
            rune == 0x0D ||
            (rune >= 0x20 && rune != 0x7F);
      }).length;
      if (decoded.isEmpty || printable / decoded.length < 0.85) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  static Uint8List? _findTlv(Uint8List data, int targetType) {
    var offset = 0;
    while (offset + 4 <= data.length) {
      final type = (data[offset] << 8) | data[offset + 1];
      final length = (data[offset + 2] << 8) | data[offset + 3];
      final valueStart = offset + 4;
      final valueEnd = valueStart + length;
      if (valueEnd > data.length) {
        return null;
      }
      if (type == targetType) {
        return Uint8List.sublistView(data, valueStart, valueEnd);
      }
      offset = valueEnd;
    }
    return null;
  }

  static Map<int, Uint8List> _parseTlvs(Uint8List data) {
    final result = <int, Uint8List>{};
    var offset = 0;
    while (offset + 4 <= data.length) {
      final type = (data[offset] << 8) | data[offset + 1];
      final length = (data[offset + 2] << 8) | data[offset + 3];
      final valueStart = offset + 4;
      final valueEnd = valueStart + length;
      if (valueEnd > data.length) {
        throw const FormatException('Truncated TLV payload');
      }
      result[type] = Uint8List.sublistView(data, valueStart, valueEnd);
      offset = valueEnd;
    }
    return result;
  }

  static int? _readUint16(Uint8List? bytes) {
    if (bytes == null || bytes.length < 2) {
      return null;
    }
    return (bytes[0] << 8) | bytes[1];
  }

  static String _authenticationLabel(int? value) {
    switch (value) {
      case 0x0001:
        return 'Open';
      case 0x0002:
        return 'WPA Personal';
      case 0x0004:
        return 'Shared';
      case 0x0008:
        return 'WPA Enterprise';
      case 0x0010:
        return 'WPA2 Enterprise';
      case 0x0020:
        return 'WPA2 Personal';
      case 0x0022:
        return 'WPA/WPA2 Personal';
      default:
        return value == null ? 'Unknown' : 'Unknown (0x${value.toRadixString(16)})';
    }
  }

  static String _encryptionLabel(int? value) {
    switch (value) {
      case 0x0001:
        return 'None';
      case 0x0002:
        return 'WEP';
      case 0x0004:
        return 'TKIP';
      case 0x0008:
        return 'AES';
      case 0x000C:
        return 'AES/TKIP';
      default:
        return value == null ? 'Unknown' : 'Unknown (0x${value.toRadixString(16)})';
    }
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}…';
  }

  static String _safe(String Function() read) {
    try {
      return read();
    } on Object {
      return '(unavailable)';
    }
  }
}
