import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef/ndef.dart' as ndef;

/// Wi-Fi security modes supported by the Wi-Fi Simple Configuration (WSC)
/// payload builder.
enum WifiSecurity { wpaWpa2, wep, open }

extension WifiSecurityInfo on WifiSecurity {
  String get label {
    switch (this) {
      case WifiSecurity.wpaWpa2:
        return 'WPA/WPA2';
      case WifiSecurity.wep:
        return 'WEP';
      case WifiSecurity.open:
        return 'Open/None';
    }
  }

  bool get requiresPassword => this != WifiSecurity.open;

  int get _authenticationType {
    switch (this) {
      case WifiSecurity.wpaWpa2:
        return 0x0020;
      case WifiSecurity.wep:
        return 0x0001;
      case WifiSecurity.open:
        return 0x0001;
    }
  }

  int get _encryptionType {
    switch (this) {
      case WifiSecurity.wpaWpa2:
        return 0x0008;
      case WifiSecurity.wep:
        return 0x0002;
      case WifiSecurity.open:
        return 0x0001;
    }
  }
}

/// Credentials used to build a Wi-Fi NDEF record.
class WifiCredentials {
  const WifiCredentials({
    required this.ssid,
    this.password = '',
    this.security = WifiSecurity.wpaWpa2,
  });

  final String ssid;
  final String password;
  final WifiSecurity security;
}

/// Contact fields used to build a vCard 3.0 NDEF record.
class VCardData {
  const VCardData({
    this.firstName = '',
    this.lastName = '',
    this.organization = '',
    this.title = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.street = '',
    this.city = '',
    this.region = '',
    this.postalCode = '',
    this.country = '',
    this.note = '',
  });

  final String firstName;
  final String lastName;
  final String organization;
  final String title;
  final String phone;
  final String email;
  final String website;
  final String street;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String note;

  String get displayName {
    final name = '${firstName.trim()} ${lastName.trim()}'.trim();
    if (name.isNotEmpty) {
      return name;
    }
    if (organization.trim().isNotEmpty) {
      return organization.trim();
    }
    return 'Contact';
  }
}

/// Builders for the NDEF record types supported by SasaTap.
class NdefBuilder {
  const NdefBuilder._();

  /// Builds a well-known URI record.
  ///
  /// Values without a scheme are treated as web URLs and prefixed with
  /// `https://`. Supported schemes include `http`, `https`, `tel`, `mailto`,
  /// `geo`, `sms` and custom app schemes.
  static ndef.UriRecord uri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Enter a URI or URL to encode.');
    }
    final candidate = RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed)
        ? trimmed
        : 'https://$trimmed';
    final parsed = Uri.tryParse(candidate);
    if (parsed == null || !parsed.hasScheme) {
      throw const FormatException('Enter a valid URI or URL.');
    }
    return ndef.UriRecord.fromUri(parsed);
  }

  /// Builds a well-known plain text record.
  static ndef.TextRecord text(String value, {String language = 'en'}) {
    if (value.isEmpty) {
      throw const FormatException('Enter the text to encode.');
    }
    final normalizedLanguage = language.trim().isEmpty
        ? 'en'
        : language.trim().toLowerCase();
    return ndef.TextRecord(text: value, language: normalizedLanguage);
  }

  /// Builds a `text/vcard` MIME record containing a vCard 3.0 payload.
  static ndef.MimeRecord vCard(VCardData data) {
    if (data.displayName == 'Contact' &&
        data.phone.isEmpty &&
        data.email.isEmpty &&
        data.website.isEmpty) {
      throw const FormatException(
        'Add at least a name, phone number, email address or website.',
      );
    }
    final vcard = _buildVCard(data);
    return ndef.MimeRecord(
      decodedType: 'text/vcard',
      payload: Uint8List.fromList(utf8.encode(vcard)),
    );
  }

  /// Builds a `application/vnd.wfa.wsc` MIME record for Wi-Fi onboarding.
  ///
  /// The payload follows the Wi-Fi Simple Configuration Credential format:
  /// a Credential TLV (0x100E) wrapping the network index, SSID,
  /// authentication type, encryption type, network key and broadcast MAC.
  /// Android recognises this record and can show its native Wi-Fi prompt.
  static ndef.MimeRecord wifi(WifiCredentials credentials) {
    final ssid = credentials.ssid.trim();
    if (ssid.isEmpty) {
      throw const FormatException('Enter the Wi-Fi network name (SSID).');
    }
    if (utf8.encode(ssid).length > 32) {
      throw const FormatException(
        'Wi-Fi network names cannot exceed 32 bytes.',
      );
    }
    if (credentials.security.requiresPassword) {
      if (credentials.security == WifiSecurity.wpaWpa2 &&
          (credentials.password.length < 8 ||
              credentials.password.length > 63)) {
        throw const FormatException(
          'WPA/WPA2 passwords must contain 8 to 63 characters.',
        );
      }
      if (credentials.security == WifiSecurity.wep &&
          credentials.password.length < 5) {
        throw const FormatException(
          'WEP keys must contain at least 5 characters.',
        );
      }
    }

    final credential = <int>[
      ..._tlv(0x1026, _uint16(1)),
      ..._tlv(0x1045, utf8.encode(ssid)),
      ..._tlv(0x1003, _uint16(credentials.security._authenticationType)),
      ..._tlv(0x100F, _uint16(credentials.security._encryptionType)),
      if (credentials.security.requiresPassword)
        ..._tlv(0x1027, utf8.encode(credentials.password)),
      ..._tlv(0x1020, const <int>[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
    ];

    return ndef.MimeRecord(
      decodedType: 'application/vnd.wfa.wsc',
      payload: Uint8List.fromList(_tlv(0x100E, credential)),
    );
  }

  /// Builds an arbitrary MIME record. Useful for advanced integrations.
  static ndef.MimeRecord mime(String mediaType, Uint8List payload) {
    final normalizedType = mediaType.trim();
    if (!RegExp(
      r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+/[A-Za-z0-9!#$%&'*+.^_`|~-]+$",
    ).hasMatch(normalizedType)) {
      throw const FormatException(
        'Enter a valid MIME type, such as application/octet-stream.',
      );
    }
    return ndef.MimeRecord(decodedType: normalizedType, payload: payload);
  }

  /// Returns the encoded NDEF message size, in bytes.
  static int encodedSize(List<ndef.NDEFRecord> records) =>
      ndef.encodeNdefMessage(records).length;

  static List<int> _uint16(int value) => [value >> 8, value & 0xFF];

  static List<int> _tlv(int type, List<int> value) => [
    type >> 8,
    type & 0xFF,
    value.length >> 8,
    value.length & 0xFF,
    ...value,
  ];

  static String _buildVCard(VCardData data) {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:${_escape(data.lastName)};${_escape(data.firstName)};;;',
      'FN:${_escape(data.displayName)}',
      if (data.organization.trim().isNotEmpty)
        'ORG:${_escape(data.organization)}',
      if (data.title.trim().isNotEmpty) 'TITLE:${_escape(data.title)}',
      if (data.phone.trim().isNotEmpty) 'TEL;TYPE=CELL:${_escape(data.phone)}',
      if (data.email.trim().isNotEmpty)
        'EMAIL;TYPE=INTERNET:${_escape(data.email)}',
      if (data.website.trim().isNotEmpty) 'URL:${_escape(data.website.trim())}',
      if (_hasAddress(data))
        'ADR;TYPE=WORK:;;${_escape(data.street)};${_escape(data.city)};'
            '${_escape(data.region)};${_escape(data.postalCode)};'
            '${_escape(data.country)}',
      if (data.note.trim().isNotEmpty) 'NOTE:${_escape(data.note)}',
      'END:VCARD',
    ];
    return lines.map(_foldLine).join('\r\n');
  }

  static bool _hasAddress(VCardData data) =>
      data.street.trim().isNotEmpty ||
      data.city.trim().isNotEmpty ||
      data.region.trim().isNotEmpty ||
      data.postalCode.trim().isNotEmpty ||
      data.country.trim().isNotEmpty;

  static String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');

  /// Folds a vCard line at 75 UTF-8 octets, as required by RFC 6350.
  static String _foldLine(String line) {
    final encoded = utf8.encode(line);
    if (encoded.length <= 75) {
      return line;
    }
    final buffer = StringBuffer();
    var currentOctets = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final octets = utf8.encode(character).length;
      if (currentOctets + octets > 75) {
        buffer.write('\r\n ');
        currentOctets = 1;
      }
      buffer.write(character);
      currentOctets += octets;
    }
    return buffer.toString();
  }
}
