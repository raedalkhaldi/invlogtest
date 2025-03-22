import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';

class CheckInService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new check-in
  Future<CheckInModel> createCheckIn({
    required String userId,
    required String username,
    String? displayName,
    required String restaurantName,
    required GeoPoint location,
    String? caption,
  }) async {
    try {
      final checkIn = CheckInModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        username: username,
        displayName: displayName,
        restaurantName: restaurantName,
        caption: caption,
        location: location,
        timestamp: DateTime.now(),
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
        .orderBy('timestamp', descending: true)
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
    print('CheckInService.getCheckInComments - Starting for checkInId: $checkInId'); // Debug log

    // First, try to get a single comment to test permissions
    _firestore
        .collection('comments')
        .where('checkInId', isEqualTo: checkInId)
        .get()
        .then((snapshot) {
          print('Direct Firestore query result:');
          print('Number of comments found: ${snapshot.docs.length}');
          for (var doc in snapshot.docs) {
            print('Comment data: ${doc.data()}');
          }
        })
        .catchError((error) {
          print('Error in direct Firestore query: $error');
        });
    
    return _firestore
        .collection('comments')
        .where('checkInId', isEqualTo: checkInId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          try {
            print('Stream snapshot received:');
            print('Number of documents: ${snapshot.docs.length}');
            for (var doc in snapshot.docs) {
              print('Document ID: ${doc.id}');
              print('Document data: ${doc.data()}');
            }

            final comments = snapshot.docs
                .map((doc) {
                  try {
                    final data = doc.data();
                    data['id'] = doc.id;
                    return CommentModel.fromMap(data);
                  } catch (e) {
                    print('Error parsing comment document ${doc.id}: $e');
                    print('Document data: ${doc.data()}');
                    return null;
                  }
                })
                .where((comment) => comment != null)
                .cast<CommentModel>()
                .toList();

            print('Successfully parsed ${comments.length} comments');
            return comments;
          } catch (e) {
            print('Error in getCheckInComments: $e');
            print('Stack trace: ${StackTrace.current}');
            return [];
          }
        });
  }

  // Add a comment to a check-in
  Future<CommentModel> addComment({
    required String checkInId,
    required String userId,
    required String username,
    String? displayName,
    required String text,
  }) async {
    try {
      print('CheckInService.addComment - Starting with userId: $userId'); // Debug log

      // Create a new document reference first to get the ID
      final docRef = _firestore.collection('comments').doc();
      
      final comment = CommentModel(
        id: docRef.id,
        checkInId: checkInId,
        userId: userId,
        username: username,
        displayName: displayName,
        text: text,
        createdAt: DateTime.now(),
      );

      print('CheckInService.addComment - Created comment object: ${comment.toMap()}'); // Debug log

      // Save the comment with the generated ID
      await docRef.set(comment.toMap());
      print('CheckInService.addComment - Saved comment to Firestore'); // Debug log

      // Update comment count in check-in document using a transaction
      await _firestore.runTransaction((transaction) async {
        final checkInDoc = await transaction.get(_firestore.collection('checkins').doc(checkInId));
        if (!checkInDoc.exists) {
          throw Exception('Check-in not found');
        }
        
        final currentCount = (checkInDoc.data()?['commentCount'] as num?)?.toInt() ?? 0;
        transaction.update(_firestore.collection('checkins').doc(checkInId), {
          'commentCount': currentCount + 1,
        });
      });
      print('CheckInService.addComment - Updated comment count'); // Debug log

      return comment;
    } catch (e) {
      print('Error in CheckInService.addComment: $e'); // Debug log
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}'); // Debug log
        print('Firebase error message: ${e.message}'); // Debug log
      }
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