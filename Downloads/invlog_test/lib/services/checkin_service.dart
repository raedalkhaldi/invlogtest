import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';

class CheckInService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new check-in
  Future<CheckInModel> createCheckIn({
    required String userId,
    required String restaurantName,
    required GeoPoint location,
    String? caption,
  }) async {
    try {
      final checkIn = CheckInModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        restaurantName: restaurantName,
        caption: caption,
        location: location,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('checkins')
          .doc(checkIn.id)
          .set(checkIn.toMap());

      return checkIn;
    } catch (e) {
      print('Error creating check-in: $e');
      rethrow;
    }
  }

  // Get check-ins for a user
  Stream<List<CheckInModel>> getUserCheckIns(String userId) {
    return _firestore
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CheckInModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get nearby restaurants (mock data for now)
  Future<List<Map<String, dynamic>>> getNearbyRestaurants(GeoPoint location) async {
    // TODO: Implement actual restaurant search using Google Places API
    return [
      {
        'name': 'Restaurant 1',
        'location': location,
        'rating': 4.5,
      },
      {
        'name': 'Restaurant 2',
        'location': location,
        'rating': 4.0,
      },
      {
        'name': 'Restaurant 3',
        'location': location,
        'rating': 4.8,
      },
    ];
  }

  // Like a check-in
  Future<void> likeCheckIn(String checkInId, String userId) async {
    try {
      final doc = await _firestore.collection('checkins').doc(checkInId).get();
      if (!doc.exists) return;

      final checkIn = CheckInModel.fromFirestore(doc);
      if (checkIn.likedBy.contains(userId)) {
        // Unlike
        await _firestore.collection('checkins').doc(checkInId).update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        // Like
        await _firestore.collection('checkins').doc(checkInId).update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      print('Error liking check-in: $e');
      rethrow;
    }
  }

  // Get comments for a check-in
  Stream<List<CommentModel>> getCheckInComments(String checkInId) {
    return _firestore
        .collection('comments')
        .where('checkInId', isEqualTo: checkInId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    });
  }

  // Add a comment to a check-in
  Future<CommentModel> addComment({
    required String checkInId,
    required String userId,
    required String text,
  }) async {
    try {
      final comment = CommentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        checkInId: checkInId,
        userId: userId,
        text: text,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('comments')
          .doc(comment.id)
          .set(comment.toMap());

      // Update comment count in check-in document
      await _firestore.collection('checkins').doc(checkInId).update({
        'commentCount': FieldValue.increment(1),
      });

      return comment;
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String checkInId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();
      
      // Update comment count in check-in document
      await _firestore.collection('checkins').doc(checkInId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }
} 