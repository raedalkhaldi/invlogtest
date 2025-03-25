import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';

class CheckInService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new check-in
  Future<CheckInModel> createCheckIn({
    required String userId,
    required String username,
    String? displayName,
    required String restaurantName,
    required GeoPoint location,
    String? caption,
    File? photoFile,
  }) async {
    try {
      print('Creating check-in for user: $userId'); // Debug log

      String? photoUrl;
      if (photoFile != null) {
        final ref = _storage.ref().child('checkin_photos/${DateTime.now().millisecondsSinceEpoch}');
        await ref.putFile(photoFile);
        photoUrl = await ref.getDownloadURL();
        print('Photo uploaded successfully: $photoUrl');
      }

      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      
      final checkIn = CheckInModel(
        id: now.millisecondsSinceEpoch.toString(),
        userId: userId,
        username: username,
        displayName: displayName,
        restaurantName: restaurantName,
        photoUrl: photoUrl,
        caption: caption,
        location: location,
        createdAt: now,
        likes: const [],
        likeCount: 0,
        commentCount: 0,
      );

      print('Creating check-in with data:'); // Debug log
      print('- userId: $userId');
      print('- restaurantName: $restaurantName');
      print('- createdAt: $timestamp');
      print('- id: ${checkIn.id}');

      final checkInData = checkIn.toMap();
      // Ensure createdAt is a Timestamp
      checkInData['createdAt'] = timestamp;

      await _firestore
          .collection('checkins')
          .doc(checkIn.id)
          .set(checkInData);

      // Verify the document was created
      final createdDoc = await _firestore
          .collection('checkins')
          .doc(checkIn.id)
          .get();
          
      if (createdDoc.exists) {
        print('Check-in created successfully:');
        print('- id: ${createdDoc.id}');
        print('- data: ${createdDoc.data()}');
      } else {
        print('Warning: Document not found after creation');
      }

      return checkIn;
    } catch (e) {
      print('Error creating check-in: $e');
      rethrow;
    }
  }

  // Get check-ins for a user
  Stream<List<CheckInModel>> getUserCheckIns(String userId) {
    print('Getting check-ins for user: $userId'); // Debug log
    
    try {
      // First, verify if any documents exist with a direct query
      _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) {
            print('Direct query result:');
            print('Found ${snapshot.docs.length} documents');
            if (snapshot.docs.isNotEmpty) {
              final firstDoc = snapshot.docs.first.data();
              print('Sample document:');
              print('- userId: ${firstDoc['userId']}');
              print('- createdAt: ${firstDoc['createdAt']}');
              print('- id: ${snapshot.docs.first.id}');
            }
          });

      // Set up the stream with the correct index order
      return _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)  // Changed to descending to show newest first
          .snapshots()
          .map((snapshot) {
            print('Stream query snapshot received:');
            print('Number of documents: ${snapshot.docs.length}');
            
            if (snapshot.docs.isEmpty) {
              print('No documents found. Verifying query parameters:');
              print('- Collection: checkins');
              print('- userId: $userId');
              print('- Ordered by: createdAt (descending)');
            } else {
              print('Found documents:');
              for (var doc in snapshot.docs) {
                final data = doc.data();
                print('Document ${doc.id}:');
                print('- userId: ${data['userId']}');
                print('- createdAt: ${data['createdAt']}');
                print('- restaurantName: ${data['restaurantName']}');
              }
            }

            return snapshot.docs
                .map((doc) => CheckInModel.fromFirestore(doc))
                .toList();
          })
          .handleError((error) {
            print('Error in getUserCheckIns: $error');
            if (error is FirebaseException) {
              print('Firebase error code: ${error.code}');
              print('Firebase error message: ${error.message}');
            }
            return [];
          });
    } catch (e) {
      print('Error setting up check-ins stream: $e');
      rethrow;
    }
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
      print('Attempting to like/unlike checkIn: $checkInId by user: $userId'); // Debug log
      
      final postRef = _firestore.collection('checkins').doc(checkInId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(postRef);
        if (!doc.exists) {
          print('CheckIn document not found'); // Debug log
          return;
        }

        final currentLikes = List<String>.from(doc.data()?['likes'] ?? []);
        print('Current likes array: $currentLikes'); // Debug log
        
        if (currentLikes.contains(userId)) {
          // Unlike
          print('Removing like (userId: $userId) from checkIn: $checkInId'); // Debug log
          transaction.update(postRef, {
            'likes': FieldValue.arrayRemove([userId]),
            'likeCount': FieldValue.increment(-1),
          });
        } else {
          // Like
          print('Adding like (userId: $userId) to checkIn: $checkInId'); // Debug log
          transaction.update(postRef, {
            'likes': FieldValue.arrayUnion([userId]),
            'likeCount': FieldValue.increment(1),
          });
        }
      });

      // Verify the update
      final updatedDoc = await postRef.get();
      final updatedLikes = List<String>.from(updatedDoc.data()?['likes'] ?? []);
      print('Updated likes array: $updatedLikes'); // Debug log
      
    } catch (e) {
      print('Error in likeCheckIn: $e'); // Debug log
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

  Future<void> deleteCheckIn(String checkInId) async {
    print('Deleting check-in: $checkInId'); // Debug log
    try {
      await _firestore.collection('checkins').doc(checkInId).delete();
      print('Check-in deleted successfully'); // Debug log
    } catch (e) {
      print('Error deleting check-in: $e'); // Debug log
      throw Exception('Failed to delete check-in: $e');
    }
  }
} 