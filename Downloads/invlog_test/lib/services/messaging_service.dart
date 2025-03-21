import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get or create a conversation between two users
  Future<String> getOrCreateConversation(String userId1, String userId2) async {
    // Sort user IDs to ensure consistent conversation ID
    final List<String> sortedUserIds = [userId1, userId2]..sort();
    final String conversationId = sortedUserIds.join('_');

    final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();

    if (!conversationDoc.exists) {
      // Create new conversation
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': sortedUserIds,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
      });
    }

    return conversationId;
  }

  // Send a message
  Future<void> sendMessage(String conversationId, String senderId, String receiverId, String content) async {
    final timestamp = FieldValue.serverTimestamp();

    // Add message to messages subcollection
    await _firestore.collection('conversations').doc(conversationId)
      .collection('messages').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
        'timestamp': timestamp,
      });

    // Update conversation with last message info
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTimestamp': timestamp,
      'lastMessageSenderId': senderId,
    });
  }

  // Get messages stream for a conversation
  Stream<List<Message>> getMessages(String conversationId) {
    return _firestore
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => Message.fromMap(doc.data(), doc.id)).toList();
      });
  }

  // Get conversations for a user
  Stream<List<Conversation>> getUserConversations(String userId) {
    return _firestore
      .collection('conversations')
      .where('participants', arrayContains: userId)
      .orderBy('lastMessageTimestamp', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => Conversation.fromMap(doc.data(), doc.id)).toList();
      });
  }
} 