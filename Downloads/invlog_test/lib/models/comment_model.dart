import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String checkInId;
  final String userId;
  final String username;
  final String? displayName;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.checkInId,
    required this.userId,
    required this.username,
    this.displayName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'checkInId': checkInId,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    print('Creating CommentModel from map: $map'); // Debug log

    final createdAt = map['createdAt'];
    final DateTime parsedCreatedAt;
    if (createdAt is Timestamp) {
      parsedCreatedAt = createdAt.toDate();
    } else if (createdAt is String) {
      parsedCreatedAt = DateTime.parse(createdAt);
    } else {
      parsedCreatedAt = DateTime.now();
      print('Warning: Invalid createdAt format in comment: $createdAt'); // Debug log
    }

    return CommentModel(
      id: map['id']?.toString() ?? '',
      checkInId: map['checkInId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      displayName: map['displayName']?.toString(),
      text: map['text']?.toString() ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    data['id'] = doc.id;
    print('Creating CommentModel from Firestore data: $data'); // Debug log
    return CommentModel.fromMap(data);
  }

  @override
  String toString() {
    return 'CommentModel(id: $id, checkInId: $checkInId, userId: $userId, username: $username, displayName: $displayName, text: $text, createdAt: $createdAt)';
  }
} 