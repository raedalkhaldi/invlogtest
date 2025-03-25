import 'package:cloud_firestore/cloud_firestore.dart';
import 'comment.dart';

class CheckIn {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final List<String> likes;
  final bool isLiked;
  final List<Comment> comments;
  final String? placeName;
  final String? caption;

  int get likeCount => likes.length;

  CheckIn({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    required this.likes,
    required this.isLiked,
    required this.comments,
    this.placeName,
    this.caption,
  });

  factory CheckIn.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else {
        return DateTime.now(); // Fallback
      }
    }

    final comments = (map['comments'] as List<dynamic>?)?.map((comment) {
      if (comment is Map<String, dynamic>) {
        return Comment.fromMap(comment);
      }
      return Comment(
        id: '', 
        userId: '', 
        username: '', 
        content: '', 
        timestamp: DateTime.now()
      );
    }).toList() ?? [];

    final likes = (map['likes'] as List<dynamic>?)?.map((like) => like.toString()).toList() ?? [];

    return CheckIn(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      displayName: map['displayName']?.toString(),
      content: map['content']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      timestamp: parseTimestamp(map['timestamp']),
      likes: likes,
      isLiked: map['isLiked'] as bool? ?? false,
      comments: comments,
      placeName: map['placeName']?.toString(),
      caption: map['caption']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'isLiked': isLiked,
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'placeName': placeName,
      'caption': caption,
    };
  }
} 