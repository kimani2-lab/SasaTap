import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/core/ndef_builder.dart';
import 'package:sasatap/core/ndef_inspector.dart';

void main() {
  group('NdefBuilder', () {
    test('adds https to bare web addresses', () {
      final record = NdefBuilder.uri('example.com');

      expect(record.uriString, 'https://example.com');
      expect(NdefBuilder.encodedSize([record]), greaterThan(0));
    });

    test('preserves supported URI schemes', () {
      final record = NdefBuilder.uri('tel:+254700000000');

      expect(record.uriString, 'tel:+254700000000');
    });

    test('builds a text record with a normalized language', () {
      final record = NdefBuilder.text('Karibu', language: ' SW ');

      expect(record.text, 'Karibu');
      expect(record.language, 'sw');
      expect(record.encodingString, 'UTF-8');
    });

    test('rejects empty URI and text values', () {
      expect(() => NdefBuilder.uri('   '), throwsFormatException);
      expect(() => NdefBuilder.text(''), throwsFormatException);
    });

    test('builds a vCard MIME record', () {
      final record = NdefBuilder.vCard(
        const VCardData(
          firstName: 'Amina',
          lastName: 'Otieno',
          phone: '+254700000000',
          email: 'amina@example.com',
        ),
      );

      expect(record.decodedType, 'text/vcard');
      final view = NdefInspector.inspect([record]).single;
      expect(view.kind, 'vCard');
      expect(view.details['Preview'], contains('BEGIN:VCARD'));
      expect(view.details['Preview'], contains('Amina'));
    });

    test('builds a Wi-Fi WSC record', () {
      final record = NdefBuilder.wifi(
        const WifiCredentials(ssid: 'SasaNet', password: 'supersecret'),
      );

      expect(record.decodedType, 'application/vnd.wfa.wsc');
      final view = NdefInspector.inspect([record]).single;
      expect(view.kind, 'Wi-Fi');
      expect(view.details['SSID'], 'SasaNet');
    });

    test('encodes Android-compatible Wi-Fi WSC TLVs', () {
      final record = NdefBuilder.wifi(
        const WifiCredentials(
          ssid: 'SasaNet',
          password: 'supersecret',
          security: WifiSecurity.wpaWpa2,
        ),
      );

      final credential = _tlvValue(record.payload!, 0x100E);
      expect(credential, isNotNull);
      expect(_tlvValue(credential!, 0x1026), <int>[0x00, 0x01]);
      expect(_tlvValue(credential, 0x1045), utf8.encode('SasaNet'));
      expect(_tlvValue(credential, 0x1003), <int>[0x00, 0x20]);
      expect(_tlvValue(credential, 0x100F), <int>[0x00, 0x08]);
      expect(_tlvValue(credential, 0x1027), utf8.encode('supersecret'));
      expect(_tlvValue(credential, 0x1020), <int>[
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);
    });

    test('omits the network key for open Wi-Fi', () {
      final record = NdefBuilder.wifi(
        const WifiCredentials(ssid: 'SasaGuest', security: WifiSecurity.open),
      );

      final credential = _tlvValue(record.payload!, 0x100E)!;
      expect(_tlvValue(credential, 0x1003), <int>[0x00, 0x01]);
      expect(_tlvValue(credential, 0x100F), <int>[0x00, 0x01]);
      expect(_tlvValue(credential, 0x1027), isNull);
      expect(_tlvValue(credential, 0x1020), hasLength(6));
    });

    test('encodes WEP credentials with WEP encryption', () {
      final record = NdefBuilder.wifi(
        const WifiCredentials(
          ssid: 'OldRouter',
          password: 'abcde',
          security: WifiSecurity.wep,
        ),
      );

      final credential = _tlvValue(record.payload!, 0x100E)!;
      expect(_tlvValue(credential, 0x1003), <int>[0x00, 0x01]);
      expect(_tlvValue(credential, 0x100F), <int>[0x00, 0x02]);
      expect(_tlvValue(credential, 0x1027), utf8.encode('abcde'));
    });

    test('builds a custom MIME record from raw bytes', () {
      final record = NdefBuilder.mime(
        'application/octet-stream',
        Uint8List.fromList([0x48, 0x69]),
      );

      expect(record.decodedType, 'application/octet-stream');
      expect(record.payload, [0x48, 0x69]);
    });

    test('rejects malformed custom MIME types', () {
      expect(
        () => NdefBuilder.mime('invalid-type', Uint8List(0)),
        throwsFormatException,
      );
    });

    test('requires an eight character WPA password', () {
      expect(
        () => NdefBuilder.wifi(
          const WifiCredentials(ssid: 'SasaNet', password: 'short'),
        ),
        throwsFormatException,
      );
    });

    test('allows open Wi-Fi networks without a password', () {
      final record = NdefBuilder.wifi(
        const WifiCredentials(ssid: 'SasaGuest', security: WifiSecurity.open),
      );

      expect(record.decodedType, 'application/vnd.wfa.wsc');
    });

    test('rejects a vCard with no identifying details', () {
      expect(() => NdefBuilder.vCard(const VCardData()), throwsFormatException);
    });
  });
}

List<int>? _tlvValue(List<int> data, int type) {
  var offset = 0;
  while (offset + 4 <= data.length) {
    final currentType = (data[offset] << 8) | data[offset + 1];
    final length = (data[offset + 2] << 8) | data[offset + 3];
    final valueStart = offset + 4;
    final valueEnd = valueStart + length;
    if (valueEnd > data.length) {
      return null;
    }
    if (currentType == type) {
      return data.sublist(valueStart, valueEnd);
    }
    offset = valueEnd;
  }
  return null;
}
