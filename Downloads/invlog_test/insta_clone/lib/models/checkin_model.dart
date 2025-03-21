import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInModel {
  final String id;
  final String userId;
  final String restaurantName;
  final String? photoUrl;
  final String? caption;
  final GeoPoint location;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;
  final int commentCount;

  CheckInModel({
    required this.id,
    required this.userId,
    required this.restaurantName,
    this.photoUrl,
    this.caption,
    required this.location,
    required this.createdAt,
    this.likes = 0,
    this.likedBy = const [],
    this.commentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'restaurantName': restaurantName,
      'photoUrl': photoUrl,
      'caption': caption,
      'location': location,
      'createdAt': createdAt,
      'likes': likes,
      'likedBy': likedBy,
      'commentCount': commentCount,
    };
  }

  factory CheckInModel.fromMap(Map<String, dynamic> map) {
    return CheckInModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      photoUrl: map['photoUrl'],
      caption: map['caption'],
      location: map['location'] as GeoPoint,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      likes: map['likes'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
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
    String? restaurantName,
    String? photoUrl,
    String? caption,
    GeoPoint? location,
    DateTime? createdAt,
    int? likes,
    List<String>? likedBy,
    int? commentCount,
  }) {
    return CheckInModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      restaurantName: restaurantName ?? this.restaurantName,
      photoUrl: photoUrl ?? this.photoUrl,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      commentCount: commentCount ?? this.commentCount,
    );
  }
} 