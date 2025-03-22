class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? profileImageUrl;
  final List<String>? checkIns;
  final List<String>? following;
  final List<String>? followers;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.profileImageUrl,
    this.checkIns,
    this.following,
    this.followers,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      username: map['username'] ?? '',
      displayName: map['displayName'],
      bio: map['bio'],
      profileImageUrl: map['profileImageUrl'],
      checkIns: List<String>.from(map['checkIns'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'checkIns': checkIns,
      'following': following,
      'followers': followers,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    List<String>? checkIns,
    List<String>? following,
    List<String>? followers,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      checkIns: checkIns ?? this.checkIns,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 