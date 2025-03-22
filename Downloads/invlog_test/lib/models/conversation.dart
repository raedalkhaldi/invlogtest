import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final String lastMessageSenderId;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.lastMessageSenderId,
    this.unreadCount = 0,
  });

  // Getter for participantIds (same as participants)
  List<String> get participantIds => participants;

  factory Conversation.fromMap(Map<String, dynamic> map, String id) {
    return Conversation(
      id: id,
      participants: List<String>.from(map['participants']),
      lastMessage: map['lastMessage'] as String,
      lastMessageTimestamp: (map['lastMessageTimestamp'] as Timestamp).toDate(),
      lastMessageSenderId: map['lastMessageSenderId'] as String,
      unreadCount: map['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': Timestamp.fromDate(lastMessageTimestamp),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
    };
  }

  // Helper method to get the content of the last message
  String get content => lastMessage;
} 