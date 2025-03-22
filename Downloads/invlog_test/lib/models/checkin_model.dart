import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInModel {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String restaurantName;
  final String? caption;
  final GeoPoint location;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final int commentCount;

  CheckInModel({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    required this.restaurantName,
    this.caption,
    required this.location,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.commentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'restaurantName': restaurantName,
      'caption': caption,
      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'likedBy': likedBy,
      'commentCount': commentCount,
    };
  }

  factory CheckInModel.fromMap(Map<String, dynamic> map) {
    print('Raw map data received: $map'); // Debug log to see incoming data

    List<String> parseLikedBy(dynamic value) {
      if (value == null) return [];
      if (value is int) return [];
      if (value is String) return [value];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    int parseNumber(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;  // Remove Iterable check as it's causing issues
    }

    final timestamp = map['timestamp'];
    final DateTime parsedTimestamp;
    if (timestamp is Timestamp) {
      parsedTimestamp = timestamp.toDate();
    } else if (timestamp is String) {
      parsedTimestamp = DateTime.parse(timestamp);
    } else {
      parsedTimestamp = DateTime.now();
    }

    // Ensure restaurantName is properly extracted
    String parseRestaurantName(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return CheckInModel(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      displayName: map['displayName']?.toString(),
      restaurantName: parseRestaurantName(map['restaurantName']),
      caption: map['caption']?.toString(),
      location: map['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      timestamp: parsedTimestamp,
      likes: parseNumber(map['likes']),
      likedBy: parseLikedBy(map['likedBy']),
      commentCount: parseNumber(map['commentCount']),
    );
  }

  factory CheckInModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    data['id'] = doc.id;
    print('Creating CheckInModel from Firestore data: $data'); // Debug log
    print('Restaurant name from Firestore: ${data['restaurantName']}'); // Debug log for restaurant name
    print('Place name from Firestore: ${data['placeName']}'); // Debug log for place name
    return CheckInModel.fromMap(data);
  }

  CheckInModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? displayName,
    String? restaurantName,
    String? caption,
    GeoPoint? location,
    DateTime? timestamp,
    int? likes,
    List<String>? likedBy,
    int? commentCount,
  }) {
    return CheckInModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      restaurantName: restaurantName ?? this.restaurantName,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      commentCount: commentCount ?? this.commentCount,
    );
  }
} 