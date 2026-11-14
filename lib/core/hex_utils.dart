import 'dart:typed_data';

/// Converts bytes to an uppercase, space-separated hexadecimal string.
///
/// Returns an empty string for null or empty input. Set [spaced] to `false`
/// for a compact representation (for example when sending APDUs).
String bytesToHex(
  Uint8List? bytes, {
  bool upperCase = true,
  bool spaced = true,
}) {
  if (bytes == null || bytes.isEmpty) {
    return '';
  }
  final raw = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  final value = upperCase ? raw.toUpperCase() : raw;
  if (!spaced) {
    return value;
  }
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index += 2) {
    if (index > 0) {
      buffer.write(' ');
    }
    buffer.write(value.substring(index, index + 2));
  }
  return buffer.toString();
}

/// Parses a hexadecimal string, ignoring spaces, colons and dashes.
///
/// Throws a [FormatException] when the cleaned input has an odd number of
/// digits or contains non-hexadecimal characters.
Uint8List hexToBytes(String hex) {
  final normalized = hex.replaceAll(RegExp(r'[\s:\-]'), '');
  if (normalized.isEmpty) {
    return Uint8List(0);
  }
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
    throw const FormatException(
      'Hexadecimal values may only contain 0-9, A-F, spaces, colons or dashes.',
    );
  }
  if (normalized.length.isOdd) {
    throw const FormatException(
      'Hexadecimal values must contain an even number of digits.',
    );
  }
  final bytes = Uint8List(normalized.length ~/ 2);
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = int.parse(
      normalized.substring(index * 2, (index * 2) + 2),
      radix: 16,
    );
  }
  return bytes;
}

/// Normalizes a tag UID so stored automation rules always match scans.
///
/// UIDs are represented as uppercase hexadecimal strings without separators.
String normalizeUid(String raw) =>
    raw.replaceAll(RegExp(r'[\s:\-]'), '').toUpperCase();

/// Returns a friendly, grouped UID representation, e.g. `04 A2 1B 8C`.
String formatUid(String raw) {
  final normalized = normalizeUid(raw);
  if (normalized.isEmpty) {
    return raw;
  }
  final buffer = StringBuffer();
  for (var index = 0; index < normalized.length; index += 2) {
    if (index > 0) {
      buffer.write(' ');
    }
    final end = index + 2 <= normalized.length ? index + 2 : normalized.length;
    buffer.write(normalized.substring(index, end));
  }
  return buffer.toString();
}

/// Returns true when [value] contains only hexadecimal characters and has an
/// even number of digits. Whitespace, colons and dashes are ignored.
bool isValidHex(String value) {
  final normalized = value.replaceAll(RegExp(r'[\s:\-]'), '');
  if (normalized.isEmpty || normalized.length.isOdd) {
    return false;
  }
  return RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized);
}
