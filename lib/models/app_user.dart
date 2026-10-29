class AppUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String address;
  final String profileImage;
  final String bannerImage;
  final String bio;
  final bool isPrivate;
  final bool isFollowing;
  final bool followRequestPending;

  const AppUser({
    required this.id,
    required this.name,
    this.username = '',
    this.email = '',
    this.address = '',
    this.profileImage = '',
    this.bannerImage = '',
    this.bio = '',
    this.isPrivate = false,
    this.isFollowing = false,
    this.followRequestPending = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'ผู้ใช้').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      profileImage: (json['profileImage'] ?? '').toString(),
      bannerImage: (json['bannerImage'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      isPrivate: json['isPrivate'] == true,
      isFollowing: json['isFollowing'] == true,
      followRequestPending: json['followRequestPending'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'address': address,
    'profileImage': profileImage,
    'bannerImage': bannerImage,
    'bio': bio,
    'isPrivate': isPrivate,
    'isFollowing': isFollowing,
    'followRequestPending': followRequestPending,
  };
}
