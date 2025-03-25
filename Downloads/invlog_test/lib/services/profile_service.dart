import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .get();
    return result.docs.isEmpty;
  }

  // Create or update user profile
  Future<void> createOrUpdateProfile(UserProfile profile) async {
    final userRef = _firestore.collection('users').doc(profile.id);
    
    // Check if username is taken by another user
    if (profile.username.isNotEmpty) {
      final existingUser = await _firestore
          .collection('users')
          .where('username', isEqualTo: profile.username.toLowerCase())
          .where('id', isNotEqualTo: profile.id)
          .get();
      
      if (existingUser.docs.isNotEmpty) {
        throw Exception('Username is already taken');
      }
    }

    // Prepare profile data
    final profileData = {
      'id': profile.id,
      'username': profile.username.toLowerCase(),
      'displayName': profile.displayName ?? profile.username,
      'bio': profile.bio ?? 'Hello! I am using InvLog',
      'profileImageUrl': profile.profileImageUrl,
      'checkIns': profile.checkIns ?? [],
      'following': profile.following ?? [],
      'followers': profile.followers ?? [],
      'createdAt': Timestamp.fromDate(profile.createdAt),
    };

    await userRef.set(profileData, SetOptions(merge: true));
  }

  // Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get user profile stream
  Stream<UserProfile?> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromMap(doc.data()!, doc.id) : null);
  }

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      return getUserProfile(user.uid);
    }
    return null;
  }

  // Update username
  Future<void> updateUsername(String uid, String newUsername) async {
    if (!await isUsernameAvailable(newUsername)) {
      throw Exception('Username is already taken');
    }

    await createOrUpdateProfile(UserProfile(
      id: uid,
      username: newUsername.toLowerCase(),
      displayName: '',
      bio: '',
      followers: [],
      following: [],
      createdAt: DateTime.now(),
    ));
  }

  // Update user profile
  Future<void> updateProfile(
    String userId, {
    String? displayName,
    String? bio,
    String? profileImageUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

    await _firestore.collection('users').doc(userId).update(updates);
  }

  // Get user's check-ins stream
  Stream<List<CheckInModel>> getUserCheckInsStream(String userId) {
    try {
      print('Fetching check-ins for user: $userId'); // Debug log
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user found'); // Debug log
        return Stream.value([]);
      }
      print('Current authenticated user: ${user.uid}'); // Debug log
      
      return _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: false)  // Changed to match index (Ascending)
          .orderBy('__name__', descending: true)
          .snapshots()
          .map((snapshot) {
            print('Got ${snapshot.docs.length} check-ins'); // Debug log
            return snapshot.docs
                .map((doc) => CheckInModel.fromFirestore(doc))
                .toList();
          })
          .handleError((error) {
            print('Error in check-ins stream: $error'); // Debug log
            return [];
          });
    } catch (e) {
      print('Error in getUserCheckInsStream: $e');
      rethrow;
    }
  }

  // Get user's liked posts stream
  Stream<List<CheckInModel>> getLikedPostsStream(String userId) {
    print('Getting liked posts for user: $userId'); // Debug log
    
    try {
      // First, verify if any documents exist with a direct query
      _firestore
          .collection('checkins')
          .where('likes', arrayContains: userId)
          .get()
          .then((snapshot) {
            print('Direct query result:');
            print('Found ${snapshot.docs.length} documents');
            if (snapshot.docs.isNotEmpty) {
              final firstDoc = snapshot.docs.first.data();
              print('Sample document:');
              print('- likes: ${firstDoc['likes']}');
              print('- createdAt: ${firstDoc['createdAt']}');
              print('- id: ${snapshot.docs.first.id}');
            }
          })
          .catchError((error) {
            print('Error in direct query: $error');
          });

      // Set up the stream with the correct index order
      return _firestore
          .collection('checkins')
          .where('likes', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .orderBy('__name__', descending: true)
          .snapshots()
          .map((snapshot) {
            print('Stream query snapshot received:');
            print('Number of documents: ${snapshot.docs.length}');
            
            if (snapshot.docs.isEmpty) {
              print('No documents found. Verifying query parameters:');
              print('- Collection: checkins');
              print('- Looking for userId: $userId in likes array');
              print('- Ordered by: createdAt (descending)');
              print('- Ordered by: __name__ (descending)');
            } else {
              print('Found documents:');
              for (var doc in snapshot.docs) {
                final data = doc.data();
                print('Document ${doc.id}:');
                print('- likes: ${data['likes']}');
                print('- createdAt: ${data['createdAt']}');
              }
            }

            return snapshot.docs
                .map((doc) => CheckInModel.fromFirestore(doc))
                .toList();
          })
          .handleError((error) {
            print('Error in getLikedPostsStream: $error');
            if (error is FirebaseException) {
              print('Firebase error code: ${error.code}');
              print('Firebase error message: ${error.message}');
            }
            return [];
          });
    } catch (e) {
      print('Error setting up likes stream: $e');
      rethrow;
    }
  }

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    if (currentUser.uid == targetUserId) throw Exception('Cannot follow yourself');

    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    
    // Add to current user's following list
    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId])
    });
    
    // Add to target user's followers list
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([currentUser.uid])
    });
    
    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    
    // Remove from current user's following list
    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId])
    });
    
    // Remove from target user's followers list
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([currentUser.uid])
    });
    
    await batch.commit();
  }

  // Check if current user is following a user
  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) return false;

    final following = List<String>.from(userDoc.data()?['following'] ?? []);
    return following.contains(targetUserId);
  }

  // Get followers stream
  Stream<List<UserProfile>> getFollowersStream(String userId) {
    return _firestore
        .collection('users')
        .where('following', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get following stream
  Stream<List<UserProfile>> getFollowingStream(String userId) {
    return _firestore
        .collection('users')
        .where('followers', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Like/Unlike methods with transaction
  Future<void> likePost(String userId, String postId) async {
    final postRef = _firestore.collection('checkins').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception('Post not found');
      
      final currentLikes = List<String>.from(postDoc.data()?['likes'] ?? []);
      if (!currentLikes.contains(userId)) {
        print('Adding like for user $userId to post $postId'); // Debug log
        transaction.update(postRef, {
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': (postDoc.data()?['likeCount'] ?? 0) + 1
        });
      }
    });
  }

  Future<void> unlikePost(String userId, String postId) async {
    final postRef = _firestore.collection('checkins').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception('Post not found');
      
      final currentLikes = List<String>.from(postDoc.data()?['likes'] ?? []);
      if (currentLikes.contains(userId)) {
        print('Removing like for user $userId from post $postId'); // Debug log
        transaction.update(postRef, {
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': (postDoc.data()?['likeCount'] ?? 1) - 1
        });
      }
    });
  }

  Future<bool> isPostLiked(String userId, String postId) async {
    final doc = await _firestore.collection('checkins').doc(postId).get();
    if (doc.exists) {
      final likes = List<String>.from(doc.data()?['likes'] ?? []);
      return likes.contains(userId);
    }
    return false;
  }

  Future<List<UserProfile>> searchUsers(UserProfile currentProfile, String query) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('id', isNotEqualTo: currentProfile.id)
        .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username', isLessThan: '${query.toLowerCase()}z')
        .get();

    return querySnapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.id).set(profile.toMap());
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // Add comment with transaction to update comment count
  Future<void> addComment(CommentModel comment) async {
    final batch = _firestore.batch();
    
    // Add the comment
    final commentRef = _firestore.collection('comments').doc();
    final commentData = comment.toMap();
    commentData['id'] = commentRef.id;
    batch.set(commentRef, commentData);
    
    // Update check-in's comment count
    final checkInRef = _firestore.collection('checkins').doc(comment.checkInId);
    batch.update(checkInRef, {
      'commentCount': FieldValue.increment(1)
    });
    
    await batch.commit();
  }

  // Add this method to ProfileService class
  Future<void> cleanupLikedByField() async {
    try {
      print('Starting likedBy field cleanup...');
      final QuerySnapshot checkins = await _firestore.collection('checkins').get();
      
      int count = 0;
      for (var doc in checkins.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('likedBy')) {
          await doc.reference.update({
            'likedBy': FieldValue.delete()
          });
          count++;
        }
      }
      print('Cleaned up likedBy field from $count documents');
    } catch (e) {
      print('Error during cleanup: $e');
      rethrow;
    }
  }

  Stream<int> getCheckInCountStream(String userId) {
    print('Getting check-in count stream for user: $userId'); // Debug log
    try {
      // First, verify if any documents exist with a direct query
      _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) {
            print('Direct query result:');
            print('Found ${snapshot.docs.length} check-ins');
            if (snapshot.docs.isNotEmpty) {
              final firstDoc = snapshot.docs.first.data();
              print('Sample check-in:');
              print('- id: ${snapshot.docs.first.id}');
              print('- userId: ${firstDoc['userId']}');
              print('- restaurantName: ${firstDoc['restaurantName']}');
              print('- createdAt: ${firstDoc['createdAt']}');
            }
          })
          .catchError((error) {
            print('Error in direct query: $error');
          });

      // Set up the stream
      return _firestore
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
            final count = snapshot.docs.length;
            print('Stream update: Found $count check-ins for user $userId'); // Debug log
            if (count > 0) {
              print('Latest check-in:');
              final latestDoc = snapshot.docs.first.data();
              print('- id: ${snapshot.docs.first.id}');
              print('- userId: ${latestDoc['userId']}');
              print('- restaurantName: ${latestDoc['restaurantName']}');
              print('- createdAt: ${latestDoc['createdAt']}');
            }
            return count;
          })
          .handleError((error) {
            print('Error in check-in count stream: $error');
            if (error is FirebaseException) {
              print('Firebase error code: ${error.code}');
              print('Firebase error message: ${error.message}');
            }
            return 0; // Return 0 on error
          });
    } catch (e) {
      print('Error setting up check-in count stream: $e');
      return Stream.value(0); // Return a stream with 0 on setup error
    }
  }

  Stream<UserProfile> getFollowingCountStream(String userId) {
    print('Getting following count stream for user: $userId'); // Debug log
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => UserProfile.fromMap(doc.data()!, doc.id));
  }

  Stream<UserProfile> getFollowersCountStream(String userId) {
    print('Getting followers count stream for user: $userId'); // Debug log
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => UserProfile.fromMap(doc.data()!, doc.id));
  }
} 