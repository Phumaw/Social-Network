class PostComment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime? createdAt;

  const PostComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return PostComment(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (user['id'] ?? user['_id'] ?? json['user'] ?? '').toString(),
      userName: (user['name'] ?? 'ผู้ใช้').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class PostReaction {
  final String userId;
  final String type;

  const PostReaction({required this.userId, required this.type});

  factory PostReaction.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return PostReaction(
      userId: (user['id'] ?? user['_id'] ?? json['user'] ?? '').toString(),
      type: (json['type'] ?? 'Like').toString(),
    );
  }
}

class FoodPost {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String caption;
  final String imageUrl;
  final String mediaType;
  final String location;
  final DateTime? createdAt;
  final List<PostReaction> reactions;
  final List<PostComment> comments;
  final bool isFollowedByMe;
  final bool followRequestPending;

  const FoodPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.caption,
    required this.imageUrl,
    this.mediaType = 'image',
    this.userImage = '',
    this.location = '',
    this.createdAt,
    this.reactions = const [],
    this.comments = const [],
    this.isFollowedByMe = false,
    this.followRequestPending = false,
  });

  factory FoodPost.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final reactionJson = json['reactions'] is List
        ? json['reactions'] as List
        : const [];
    final commentJson = json['comments'] is List
        ? json['comments'] as List
        : const [];
    return FoodPost(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (user['id'] ?? user['_id'] ?? json['user'] ?? '').toString(),
      userName: (user['name'] ?? 'ผู้ใช้').toString(),
      userImage: (user['profileImage'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? 'image').toString(),
      location: (json['location'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      reactions: reactionJson
          .whereType<Map<String, dynamic>>()
          .map(PostReaction.fromJson)
          .toList(),
      comments: commentJson
          .whereType<Map<String, dynamic>>()
          .map(PostComment.fromJson)
          .toList(),
      isFollowedByMe: json['isFollowedByMe'] == true,
      followRequestPending: json['followRequestPending'] == true,
    );
  }

  String? reactionBy(String userId) {
    for (final reaction in reactions) {
      if (reaction.userId == userId) return reaction.type;
    }
    return null;
  }
}
