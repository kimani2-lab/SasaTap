import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved tag caches are isolated per authenticated user', () async {
    SharedPreferences.setMockInitialValues({
      SavedTagRepository.storageKeyForUser('user-a'): jsonEncode([
        _tagJson(uid: '04A1', ownerUserId: 'user-a'),
      ]),
      SavedTagRepository.storageKeyForUser('user-b'): jsonEncode([
        _tagJson(uid: '04B2', ownerUserId: 'user-b'),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final userA = SavedTagRepository(preferences, userId: 'user-a');
    final userB = SavedTagRepository(preferences, userId: 'user-b');

    await userA.load();
    await userB.load();

    expect(userA.tags.map((tag) => tag.uid), ['04A1']);
    expect(userB.tags.map((tag) => tag.uid), ['04B2']);
  });

  test('a user cannot remove another owner’s cached tag', () async {
    SharedPreferences.setMockInitialValues({
      SavedTagRepository.storageKeyForUser('user-a'): jsonEncode([
        _tagJson(uid: '04B2', ownerUserId: 'user-b'),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SavedTagRepository(preferences, userId: 'user-a');
    await repository.load();

    await expectLater(repository.delete('04B2'), throwsA(isA<StateError>()));
    expect(repository.tags.single.ownerUserId, 'user-b');
  });
}

Map<String, Object?> _tagJson({
  required String uid,
  required String ownerUserId,
}) => {
  'uid': uid,
  'standard': 'ISO 14443-3A',
  'tagType': 'nfcA',
  'manufacturer': 'NXP',
  'capacity': 144,
  'savedAt': '2026-11-16T00:00:00.000',
  'records': <Object>[],
  'writeProtected': false,
  'ownerUserId': ownerUserId,
  'organizationId': null,
};
