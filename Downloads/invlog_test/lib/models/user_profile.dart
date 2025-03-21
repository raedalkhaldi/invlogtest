import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? profileImageUrl;
  final List<String> followers;
  final List<String> following;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.profileImageUrl,
    required this.followers,
    required this.following,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
      return DateTime.now(); // Fallback value
    }

    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['displayName'] as String?,
      bio: map['bio'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'followers': followers,
      'following': following,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
} 