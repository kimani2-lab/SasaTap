import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/core/hex_utils.dart';

void main() {
  group('hex helpers', () {
    test('converts bytes to spaced uppercase hex', () {
      expect(
        bytesToHex(Uint8List.fromList([0x04, 0xA2, 0x1B])),
        '04 A2 1B',
      );
    });

    test('parses separators and validates even length', () {
      expect(hexToBytes('04:A2-1b'), [0x04, 0xA2, 0x1B]);
      expect(() => hexToBytes('ABC'), throwsFormatException);
    });

    test('normalizes and formats a UID consistently', () {
      expect(normalizeUid('04:a2 1b-8c'), '04A21B8C');
      expect(formatUid('04A21B8C'), '04 A2 1B 8C');
      expect(isValidHex('04 A2 1B 8C'), isTrue);
      expect(isValidHex('04 A2 1'), isFalse);
    });
  });
}
