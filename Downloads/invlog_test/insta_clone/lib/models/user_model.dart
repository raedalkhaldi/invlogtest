import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? photoUrl;
  final String? bio;
  final DateTime createdAt;
  final List<String> followers;
  final List<String> following;
  final int checkInCount;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.photoUrl,
    this.bio,
    required this.createdAt,
    this.followers = const [],
    this.following = const [],
    this.checkInCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt,
      'followers': followers,
      'following': following,
      'checkInCount': checkInCount,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      checkInCount: map['checkInCount'] ?? 0,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data);
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
    List<String>? followers,
    List<String>? following,
    int? checkInCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      checkInCount: checkInCount ?? this.checkInCount,
    );
  }
} 