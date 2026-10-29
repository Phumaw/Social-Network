class Community {
  final String id;
  final String name;
  final String description;
  final String type;
  final String creatorId;
  final String creatorName;
  final int memberCount;
  final bool isMember;
  final bool isAdmin;

  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.creatorId,
    required this.creatorName,
    required this.memberCount,
    required this.isMember,
    required this.isAdmin,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    final creator = json['createdBy'] is Map<String, dynamic>
        ? json['createdBy'] as Map<String, dynamic>
        : <String, dynamic>{};
    return Community(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: (json['type'] ?? 'group').toString(),
      creatorId: (creator['id'] ?? creator['_id'] ?? json['createdBy'] ?? '')
          .toString(),
      creatorName: (creator['name'] ?? 'สมาชิก').toString(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      isMember: json['isMember'] == true,
      isAdmin: json['isAdmin'] == true,
    );
  }

  bool get isPage => type == 'page';
}
