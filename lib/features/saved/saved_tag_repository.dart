import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sasatap/core/ndef_inspector.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedNdefRecord {
  const SavedNdefRecord({
    required this.kind,
    required this.type,
    required this.summary,
    required this.rawHex,
    required this.payloadSize,
  });

  final String kind;
  final String type;
  final String summary;
  final String rawHex;
  final int payloadSize;

  factory SavedNdefRecord.fromJson(Map<String, dynamic> json) {
    return SavedNdefRecord(
      kind: json['kind'] as String,
      type: json['type'] as String,
      summary: json['summary'] as String,
      rawHex: json['rawHex'] as String,
      payloadSize: json['payloadSize'] as int,
    );
  }

  Map<String, Object> toJson() => {
    'kind': kind,
    'type': type,
    'summary': summary,
    'rawHex': rawHex,
    'payloadSize': payloadSize,
  };
}

class SavedTag {
  const SavedTag({
    required this.uid,
    required this.standard,
    required this.tagType,
    required this.manufacturer,
    required this.capacity,
    required this.savedAt,
    required this.records,
  });

  final String uid;
  final String standard;
  final String tagType;
  final String manufacturer;
  final int? capacity;
  final DateTime savedAt;
  final List<SavedNdefRecord> records;

  factory SavedTag.fromScan(NfcTagScan scan) {
    return SavedTag(
      uid: scan.formattedUid,
      standard: scan.tag.standard,
      tagType: scan.tag.type.name,
      manufacturer: scan.tag.manufacturer ?? '',
      capacity: scan.tag.ndefCapacity,
      savedAt: DateTime.now(),
      records: NdefInspector.inspect(scan.records)
          .map(
            (record) => SavedNdefRecord(
              kind: record.kind,
              type: record.type,
              summary: record.summary,
              rawHex: record.rawHex,
              payloadSize: record.payloadSize,
            ),
          )
          .toList(growable: false),
    );
  }

  factory SavedTag.fromJson(Map<String, dynamic> json) {
    return SavedTag(
      uid: json['uid'] as String,
      standard: json['standard'] as String,
      tagType: json['tagType'] as String,
      manufacturer: json['manufacturer'] as String,
      capacity: json['capacity'] as int?,
      savedAt: DateTime.parse(json['savedAt'] as String),
      records: (json['records'] as List<dynamic>)
          .map(
            (record) =>
                SavedNdefRecord.fromJson(record as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'uid': uid,
    'standard': standard,
    'tagType': tagType,
    'manufacturer': manufacturer,
    'capacity': capacity,
    'savedAt': savedAt.toIso8601String(),
    'records': records.map((record) => record.toJson()).toList(),
  };
}

class SavedTagRepository extends ChangeNotifier {
  SavedTagRepository(this._preferences);

  static const storageKey = 'sasatap.saved_tags.v1';

  final SharedPreferences _preferences;
  List<SavedTag> _tags = const [];
  String? _warning;

  List<SavedTag> get tags => List.unmodifiable(_tags);

  String? get warning => _warning;

  Future<void> load() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      _tags = const [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Saved tags are not a list.');
      }
      _tags = decoded
          .map((item) => SavedTag.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
      _warning = null;
    } on FormatException catch (error) {
      _tags = const [];
      _warning = 'Saved tags could not be loaded: $error';
    } on TypeError catch (error) {
      _tags = const [];
      _warning = 'Saved tags could not be loaded: $error';
    }
  }

  Future<void> save(NfcTagScan scan) async {
    final tag = SavedTag.fromScan(scan);
    final updated = [tag, ..._tags.where((saved) => saved.uid != tag.uid)];
    await _persist(updated);
    _tags = List.unmodifiable(updated);
    _warning = null;
    notifyListeners();
  }

  Future<void> delete(String uid) async {
    final updated = _tags.where((tag) => tag.uid != uid).toList();
    await _persist(updated);
    _tags = List.unmodifiable(updated);
    notifyListeners();
  }

  Future<void> _persist(List<SavedTag> tags) async {
    final success = await _preferences.setString(
      storageKey,
      jsonEncode(tags.map((tag) => tag.toJson()).toList()),
    );
    if (!success) {
      throw StateError('Saved tags could not be written to device storage.');
    }
  }
}
