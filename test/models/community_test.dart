import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/community.dart';

void main() {
  test('reads community details and current-user permissions', () {
    final community = Community.fromJson({
      '_id': 'community-1',
      'name': 'ชมรมหนังสือ',
      'description': 'แลกเปลี่ยนหนังสือ',
      'type': 'group',
      'createdBy': {'_id': 'user-1', 'name': 'ผู้สร้าง'},
      'memberCount': 5,
      'isMember': true,
      'isAdmin': false,
    });

    expect(community.id, 'community-1');
    expect(community.name, 'ชมรมหนังสือ');
    expect(community.creatorId, 'user-1');
    expect(community.creatorName, 'ผู้สร้าง');
    expect(community.memberCount, 5);
    expect(community.isMember, isTrue);
    expect(community.isAdmin, isFalse);
    expect(community.isPage, isFalse);
  });

  test('identifies page communities', () {
    final community = Community.fromJson({'id': 'page-1', 'type': 'page'});

    expect(community.isPage, isTrue);
  });
}
