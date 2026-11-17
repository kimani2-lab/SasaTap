import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:sasatap/core/ndef_inspector.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.writeProtected = false,
    this.ownerUserId = '',
    this.organizationId,
  });

  final String uid;
  final String standard;
  final String tagType;
  final String manufacturer;
  final int? capacity;
  final DateTime savedAt;
  final List<SavedNdefRecord> records;
  final bool writeProtected;
  final String ownerUserId;
  final String? organizationId;

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
      writeProtected: json['writeProtected'] as bool? ?? false,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      organizationId: json['organizationId'] as String?,
    );
  }

  SavedTag copyWith({
    bool? writeProtected,
    String? ownerUserId,
    String? organizationId,
    bool clearOrganization = false,
  }) {
    return SavedTag(
      uid: uid,
      standard: standard,
      tagType: tagType,
      manufacturer: manufacturer,
      capacity: capacity,
      savedAt: savedAt,
      records: records,
      writeProtected: writeProtected ?? this.writeProtected,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      organizationId: clearOrganization
          ? null
          : organizationId ?? this.organizationId,
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
    'writeProtected': writeProtected,
    'ownerUserId': ownerUserId,
    'organizationId': organizationId,
  };
}

class SavedTagOrganization {
  const SavedTagOrganization({required this.id, required this.name});

  final String id;
  final String name;

  factory SavedTagOrganization.fromJson(Map<String, dynamic> json) {
    return SavedTagOrganization(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, String> toJson() => {'id': id, 'name': name};
}

class SavedTagRepository extends ChangeNotifier {
  SavedTagRepository(
    this._preferences, {
    this.userId = 'local',
    SupabaseClient? client,
  }) : _client = client;

  static const legacyStorageKey = 'sasatap.saved_tags.v1';
  static String storageKeyForUser(String userId) =>
      'sasatap.saved_tags.v2.$userId';
  static String _pendingKeyForUser(String userId) =>
      'sasatap.saved_tags.pending.v1.$userId';
  static String _organizationsKeyForUser(String userId) =>
      'sasatap.organizations.v1.$userId';

  final SharedPreferences _preferences;
  final SupabaseClient? _client;
  final String userId;
  List<SavedTag> _tags = const [];
  List<SavedTagOrganization> _organizations = const [];
  String? _warning;

  List<SavedTag> get tags => List.unmodifiable(_tags);

  List<SavedTagOrganization> get organizations =>
      List.unmodifiable(_organizations);

  String? get warning => _warning;

  Future<void> load() async {
    final raw = _preferences.getString(storageKeyForUser(userId));
    try {
      if (raw == null || raw.isEmpty) {
        _tags = const [];
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is! List<dynamic>) {
          throw const FormatException('Saved tags are not a list.');
        }
        _tags = decoded
            .map((item) {
              final tag = SavedTag.fromJson(item as Map<String, dynamic>);
              return tag.ownerUserId.isEmpty
                  ? tag.copyWith(ownerUserId: userId)
                  : tag;
            })
            .toList(growable: false);
      }
      _warning = null;
    } on FormatException catch (error) {
      _tags = const [];
      _warning = 'Saved tags could not be loaded: $error';
    } on TypeError catch (error) {
      _tags = const [];
      _warning = 'Saved tags could not be loaded: $error';
    }

    final cachedOrganizations = _preferences.getString(
      _organizationsKeyForUser(userId),
    );
    if (cachedOrganizations != null && cachedOrganizations.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedOrganizations);
        if (decoded is List<dynamic>) {
          _organizations = decoded
              .map(
                (item) =>
                    SavedTagOrganization.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false);
        }
      } on FormatException catch (error) {
        _warning = 'Saved organizations could not be loaded: $error';
      } on TypeError catch (error) {
        _warning = 'Saved organizations could not be loaded: $error';
      }
    }

    await _syncRemote();
    notifyListeners();
  }

  Future<void> save(NfcTagScan scan) async {
    await saveTag(SavedTag.fromScan(scan));
  }

  Future<void> synchronize() async {
    await _syncRemote();
    notifyListeners();
  }

  Future<void> saveTag(SavedTag tag) async {
    final ownedTag = tag.copyWith(ownerUserId: userId);
    final updated = [
      ownedTag,
      ..._tags.where(
        (saved) => saved.uid != ownedTag.uid || saved.ownerUserId != userId,
      ),
    ];
    await _persistTags(updated);
    _tags = List.unmodifiable(updated);
    await _queueMutation(ownedTag.uid, 'upsert');
    await _syncRemote();
    notifyListeners();
  }

  Future<void> delete(String uid) async {
    final hasOwnedTag = _tags.any(
      (tag) => tag.uid == uid && tag.ownerUserId == userId,
    );
    if (!hasOwnedTag) {
      throw StateError('Only the owner can remove this saved tag.');
    }
    final updated = _tags
        .where((tag) => tag.uid != uid || tag.ownerUserId != userId)
        .toList(growable: false);
    await _persistTags(updated);
    _tags = List.unmodifiable(updated);
    await _queueMutation(uid, 'delete');
    await _syncRemote();
    notifyListeners();
  }

  Future<void> markWriteProtected(String uid) async {
    var found = false;
    final updated = [
      for (final tag in _tags)
        if (tag.uid.toLowerCase() == uid.toLowerCase() &&
            tag.ownerUserId == userId)
          _markProtected(tag, () => found = true)
        else
          tag,
    ];
    if (!found) {
      throw StateError('Only the owner can update this saved tag.');
    }
    await _persistTags(updated);
    _tags = List.unmodifiable(updated);
    await _queueMutation(uid, 'upsert');
    await _syncRemote();
    notifyListeners();
  }

  Future<List<SavedTagOrganization>> loadOrganizations() async {
    final client = _client;
    if (client == null) {
      return organizations;
    }
    try {
      final rows = await client
          .from('organization_memberships')
          .select('organizations (id, name)')
          .eq('user_id', userId);
      final organizations = rows
          .map((row) {
            final organization = row['organizations'] as Map<String, dynamic>?;
            if (organization == null) {
              throw const FormatException(
                'An organization membership has no organization record.',
              );
            }
            return SavedTagOrganization.fromJson(organization);
          })
          .toList(growable: false);
      await _persistOrganizations(organizations);
      _organizations = organizations;
      _warning = null;
      notifyListeners();
      return this.organizations;
    } on PostgrestException catch (error) {
      _setSyncWarning('Organizations could not be loaded: ${error.message}');
      return organizations;
    } on AuthException catch (error) {
      _setSyncWarning('Organizations could not be loaded: ${error.message}');
      return organizations;
    } on FormatException catch (error) {
      _setSyncWarning('Organizations could not be loaded: $error');
      return organizations;
    } on ClientException catch (error) {
      _setSyncWarning(
        'Organizations are unavailable offline. Cached organizations remain '
        'available. $error',
      );
      return organizations;
    } on TimeoutException catch (error) {
      _setSyncWarning(
        'Organizations are unavailable offline. Cached organizations remain '
        'available. $error',
      );
      return organizations;
    }
  }

  Future<void> setOrganization(String uid, String? organizationId) async {
    final index = _tags.indexWhere(
      (tag) => tag.uid == uid && tag.ownerUserId == userId,
    );
    if (index < 0) {
      throw StateError('Only the owner can share this saved tag.');
    }
    if (organizationId != null &&
        !_organizations.any(
          (organization) => organization.id == organizationId,
        )) {
      throw StateError('Choose an organization this account belongs to.');
    }
    final updated = [..._tags];
    updated[index] = updated[index].copyWith(
      organizationId: organizationId,
      clearOrganization: organizationId == null,
    );
    await _persistTags(updated);
    _tags = List.unmodifiable(updated);
    await _queueMutation(uid, 'upsert');
    await _syncRemote();
    notifyListeners();
  }

  SavedTag _markProtected(SavedTag tag, VoidCallback onFound) {
    onFound();
    return tag.copyWith(writeProtected: true);
  }

  Future<void> _syncRemote() async {
    final client = _client;
    if (client == null) {
      return;
    }
    try {
      await _syncPendingMutations(client);
      final rows = await client
          .from('saved_tags')
          .select('owner_user_id, organization_id, tag_uid, tag_data');
      final remoteTags = rows
          .map((row) {
            final data = Map<String, dynamic>.from(
              row['tag_data'] as Map<String, dynamic>,
            );
            data['uid'] = row['tag_uid'] as String;
            data['ownerUserId'] = row['owner_user_id'] as String;
            data['organizationId'] = row['organization_id'] as String?;
            return SavedTag.fromJson(data);
          })
          .toList(growable: false);
      final pending = _readPendingMutations();
      final pendingOwnedTags = _tags.where(
        (tag) => tag.ownerUserId == userId && pending[tag.uid] == 'upsert',
      );
      final merged = <String, SavedTag>{};
      for (final tag in [...remoteTags, ...pendingOwnedTags]) {
        merged['${tag.ownerUserId}:${tag.uid}'] = tag;
      }
      _tags = List.unmodifiable(merged.values);
      await _persistTags(_tags);
      _warning = null;
    } on PostgrestException catch (error) {
      _setSyncWarning(
        "Cloud sync failed; this account's offline cache is still available. "
        '${error.message}',
      );
    } on AuthException catch (error) {
      _setSyncWarning(
        "Cloud sync failed; this account's offline cache is still available. "
        '${error.message}',
      );
    } on FormatException catch (error) {
      _setSyncWarning('Saved-tag sync data is invalid: $error');
    } on ClientException catch (error) {
      _setSyncWarning(
        'Cloud sync is unavailable. Changes are queued on this device. $error',
      );
    } on TimeoutException catch (error) {
      _setSyncWarning(
        'Cloud sync is unavailable. Changes are queued on this device. $error',
      );
    }
  }

  Future<void> _syncPendingMutations(SupabaseClient client) async {
    final pending = _readPendingMutations();
    for (final entry in pending.entries.toList(growable: false)) {
      if (entry.value == 'delete') {
        await client
            .from('saved_tags')
            .delete()
            .eq('owner_user_id', userId)
            .eq('tag_uid', entry.key);
      } else if (entry.value == 'upsert') {
        final tag = _tags.firstWhere(
          (saved) => saved.uid == entry.key && saved.ownerUserId == userId,
        );
        await client.from('saved_tags').upsert({
          'owner_user_id': userId,
          'organization_id': tag.organizationId,
          'tag_uid': tag.uid,
          'tag_data': tag.toJson(),
        }, onConflict: 'owner_user_id,tag_uid');
      } else {
        throw FormatException(
          'Unknown pending saved-tag operation: ${entry.value}',
        );
      }
      pending.remove(entry.key);
      await _persistPendingMutations(pending);
    }
  }

  Map<String, String> _readPendingMutations() {
    final raw = _preferences.getString(_pendingKeyForUser(userId));
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Pending saved-tag changes are invalid.');
    }
    return decoded.map((key, value) {
      if (value is! String) {
        throw const FormatException(
          'A pending saved-tag operation is invalid.',
        );
      }
      return MapEntry(key, value);
    });
  }

  Future<void> _queueMutation(String uid, String operation) async {
    final pending = _readPendingMutations()..[uid] = operation;
    await _persistPendingMutations(pending);
  }

  Future<void> _persistPendingMutations(Map<String, String> pending) async {
    final saved = await _preferences.setString(
      _pendingKeyForUser(userId),
      jsonEncode(pending),
    );
    if (!saved) {
      throw StateError('Pending saved-tag changes could not be stored.');
    }
  }

  Future<void> _persistTags(List<SavedTag> tags) async {
    final success = await _preferences.setString(
      storageKeyForUser(userId),
      jsonEncode(tags.map((tag) => tag.toJson()).toList()),
    );
    if (!success) {
      throw StateError('Saved tags could not be written to device storage.');
    }
  }

  Future<void> _persistOrganizations(
    List<SavedTagOrganization> organizations,
  ) async {
    final success = await _preferences.setString(
      _organizationsKeyForUser(userId),
      jsonEncode(
        organizations.map((organization) => organization.toJson()).toList(),
      ),
    );
    if (!success) {
      throw StateError('Organizations could not be cached on this device.');
    }
  }

  void _setSyncWarning(String message) {
    _warning = message;
    notifyListeners();
  }
}
