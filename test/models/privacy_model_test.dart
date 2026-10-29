import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/app_user.dart';
import 'package:foodiehub/models/food_post.dart';

void main() {
  test(
    'reads public user search follow state without exposing private fields',
    () {
      final user = AppUser.fromJson({
        'id': 'user-1',
        'name': 'บัญชีส่วนตัว',
        'username': 'private_user',
        'isPrivate': true,
        'isFollowing': false,
        'followRequestPending': true,
      });

      expect(user.isPrivate, isTrue);
      expect(user.isFollowing, isFalse);
      expect(user.followRequestPending, isTrue);
      expect(user.email, isEmpty);
      expect(user.address, isEmpty);
    },
  );

  test('reads pending follow request state for post author', () {
    final post = FoodPost.fromJson({
      '_id': 'post-1',
      'user': {'_id': 'user-1', 'name': 'บัญชีส่วนตัว'},
      'caption': 'โพสต์',
      'isFollowedByMe': false,
      'followRequestPending': true,
    });

    expect(post.followRequestPending, isTrue);
    expect(post.isFollowedByMe, isFalse);
  });
}
