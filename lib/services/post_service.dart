import 'package:image_picker/image_picker.dart';

import '../models/food_post.dart';
import 'api_service.dart';

class PostService {
  Future<List<FoodPost>> getPosts({
    String query = '',
    String sort = 'recent',
    bool withLocation = false,
    String? communityId,
    String? userId,
  }) async {
    final parameters = <String, String>{'sort': sort};
    if (query.trim().isNotEmpty) parameters['q'] = query.trim();
    if (withLocation) parameters['location'] = 'true';
    if (communityId != null) parameters['communityId'] = communityId;
    if (userId != null) parameters['userId'] = userId;
    final response = await ApiService.get(
      '/posts?${Uri(queryParameters: parameters).query}',
    );
    if (response is! List)
      throw const ApiException('รูปแบบข้อมูลโพสต์ไม่ถูกต้อง');
    return response
        .whereType<Map<String, dynamic>>()
        .map(FoodPost.fromJson)
        .toList();
  }

  Future<void> createPost({
    required String caption,
    required String location,
    XFile? media,
    String? mediaType,
    String? communityId,
  }) async {
    if (media == null) {
      await ApiService.post('/posts', {
        'caption': caption,
        'location': location,
        if (communityId != null) 'communityId': communityId,
      });
    } else {
      await ApiService.uploadPost(
        caption: caption,
        location: location,
        media: media,
        mediaType: mediaType ?? 'image',
        communityId: communityId,
      );
    }
  }

  Future<void> updatePost({
    required String id,
    required String caption,
    required String location,
  }) async {
    await ApiService.put('/posts/$id', {
      'caption': caption,
      'location': location,
    });
  }

  Future<void> deletePost(String id) async {
    await ApiService.delete('/posts/$id');
  }

  Future<void> setReaction(String postId, String? type) async {
    await ApiService.put('/posts/$postId/reaction', {'type': type});
  }

  Future<void> reportPost(String postId, String reason) async {
    await ApiService.post('/posts/$postId/report', {'reason': reason});
  }

  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await ApiService.put('/auth/follow/$userId', {});
    if (response is! Map<String, dynamic>) {
      throw const ApiException('เปลี่ยนสถานะติดตามไม่สำเร็จ');
    }
    return response;
  }

  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final response = await ApiService.delete('/auth/follow/$userId');
    if (response is! Map<String, dynamic>) {
      throw const ApiException('เลิกติดตามไม่สำเร็จ');
    }
    return response;
  }

  Future<void> addComment(String postId, String text) async {
    await ApiService.post('/posts/$postId/comments', {'text': text});
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await ApiService.delete('/posts/$postId/comments/$commentId');
  }
}
