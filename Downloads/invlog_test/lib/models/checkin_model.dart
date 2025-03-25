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
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }

  factory CheckInModel.fromMap(Map<String, dynamic> map) {
    // Helper function to safely convert to List<String>
    List<String> safeList(dynamic value) {
      if (value == null) return [];
      if (value is List) return List<String>.from(value.map((e) => e.toString()));
      if (value is int) return [];
      return [];
    }

    // Helper function to safely convert to int
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return CheckInModel(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      displayName: map['displayName']?.toString(),
      restaurantName: map['restaurantName']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(),
      caption: map['caption']?.toString(),
      location: map['location'] is GeoPoint 
          ? map['location'] as GeoPoint 
          : GeoPoint(0, 0),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now())
          : DateTime.now(),
      likes: safeList(map['likes']),
      likeCount: safeInt(map['likeCount']),
      commentCount: safeInt(map['commentCount']),
    );
  }

  factory CheckInModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Safely convert timestamp
    DateTime createdAt;
    try {
      final timestamp = data['createdAt'];
      if (timestamp is Timestamp) {
        createdAt = timestamp.toDate();
      } else {
        print('Warning: createdAt is not a Timestamp: $timestamp');
        createdAt = DateTime.now();
      }
    } catch (e) {
      print('Error converting timestamp: $e');
      createdAt = DateTime.now();
    }

    return CheckInModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'],
      restaurantName: data['restaurantName'] ?? '',
      photoUrl: data['photoUrl'],
      caption: data['caption'],
      location: data['location'] as GeoPoint,
      createdAt: createdAt,
      likes: List<String>.from(data['likes'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
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