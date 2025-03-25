import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInModel {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String restaurantName;
  final String? photoUrl;
  final String? caption;
  final GeoPoint location;
  final DateTime createdAt;
  final List<String> likes;
  final int likeCount;
  final int commentCount;

  CheckInModel({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    required this.restaurantName,
    this.photoUrl,
    this.caption,
    required this.location,
    required this.createdAt,
    this.likes = const [],
    this.likeCount = 0,
    this.commentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'restaurantName': restaurantName,
      'photoUrl': photoUrl,
      'caption': caption,
      'location': location,
      'createdAt': createdAt,
      'likes': likes,
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }

  factory CheckInModel.fromMap(Map<String, dynamic> map) {
    return CheckInModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'],
      restaurantName: map['restaurantName'] ?? '',
      photoUrl: map['photoUrl'],
      caption: map['caption'],
      location: map['location'] as GeoPoint,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      likes: List<String>.from(map['likes'] ?? []),
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
    );
  }

  factory CheckInModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CheckInModel.fromMap(data);
  }

  CheckInModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? displayName,
    String? restaurantName,
    String? photoUrl,
    String? caption,
    GeoPoint? location,
    DateTime? createdAt,
    List<String>? likes,
    int? likeCount,
    int? commentCount,
  }) {
    return CheckInModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      restaurantName: restaurantName ?? this.restaurantName,
      photoUrl: photoUrl ?? this.photoUrl,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
    );
  }
} 