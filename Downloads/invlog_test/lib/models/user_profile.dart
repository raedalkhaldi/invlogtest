import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? photoUrl;
  final String? profileImageUrl;
  final String? bio;
  final DateTime createdAt;
  final List<String> following;
  final List<String> followers;
  final List<String>? checkIns;

  UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.photoUrl,
    this.profileImageUrl,
    this.bio,
    required this.createdAt,
    this.following = const [],
    this.followers = const [],
    this.checkIns,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'following': following,
      'followers': followers,
      'checkIns': checkIns,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseCreatedAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return UserProfile(
      id: id,
      username: map['username'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      profileImageUrl: map['profileImageUrl'],
      bio: map['bio'],
      createdAt: parseCreatedAt(map['createdAt']),
      following: List<String>.from(map['following'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      checkIns: map['checkIns'] != null ? List<String>.from(map['checkIns']) : null,
    );
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? photoUrl,
    String? profileImageUrl,
    String? bio,
    DateTime? createdAt,
    List<String>? following,
    List<String>? followers,
    List<String>? checkIns,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      checkIns: checkIns ?? this.checkIns,
    );
  }
} 