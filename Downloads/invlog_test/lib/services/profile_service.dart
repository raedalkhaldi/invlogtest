import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/checkin.dart';
import '../models/comment.dart' as comment_model;

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

    await userRef.set(profile.toMap(), SetOptions(merge: true));
  }

  // Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserProfile.fromMap({
        'id': doc.id,
        ...doc.data()!,
      });
    }
    return null;
  }

  // Get user profile stream
  Stream<UserProfile> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => UserProfile.fromMap(doc.data()!));
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
  Stream<List<CheckIn>> getUserCheckInsStream(String userId) {
    return _firestore
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              final likedBy = List<String>.from(data['likes'] ?? []);
              final comments = (data['comments'] as List<dynamic>? ?? [])
                  .map((comment) => comment_model.Comment.fromMap(comment as Map<String, dynamic>))
                  .toList();

              final timestamp = data['timestamp'];
              final DateTime parsedTimestamp;
              if (timestamp is Timestamp) {
                parsedTimestamp = timestamp.toDate();
              } else if (timestamp is String) {
                parsedTimestamp = DateTime.parse(timestamp);
              } else {
                parsedTimestamp = DateTime.now();
              }

              return CheckIn(
                id: doc.id,
                userId: data['userId'] ?? '',
                username: data['username'] ?? '',
                displayName: data['displayName'],
                content: data['content'] ?? '',
                imageUrl: data['imageUrl'],
                timestamp: parsedTimestamp,
                likedBy: likedBy,
                isLiked: likedBy.contains(_auth.currentUser?.uid),
                comments: comments,
                placeName: data['placeName'],
                caption: data['caption'],
              );
            })
            .toList());
  }

  // Get user's liked posts stream
  Stream<List<CheckIn>> getLikedPostsStream(String userId) {
    return _firestore
        .collection('checkins')
        .where('likes', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              final likedBy = List<String>.from(data['likes'] ?? []);
              final comments = (data['comments'] as List<dynamic>? ?? [])
                  .map((comment) => comment_model.Comment.fromMap(comment as Map<String, dynamic>))
                  .toList();

              final timestamp = data['timestamp'];
              final DateTime parsedTimestamp;
              if (timestamp is Timestamp) {
                parsedTimestamp = timestamp.toDate();
              } else if (timestamp is String) {
                parsedTimestamp = DateTime.parse(timestamp);
              } else {
                parsedTimestamp = DateTime.now();
              }

              return CheckIn(
                id: doc.id,
                userId: data['userId'] ?? '',
                username: data['username'] ?? '',
                displayName: data['displayName'],
                content: data['content'] ?? '',
                imageUrl: data['imageUrl'],
                timestamp: parsedTimestamp,
                likedBy: likedBy,
                isLiked: likedBy.contains(_auth.currentUser?.uid),
                comments: comments,
                placeName: data['placeName'],
                caption: data['caption'],
              );
            })
            .toList());
  }

  // Follow user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Add targetUserId to current user's following list
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId])
    });
    
    // Add currentUserId to target user's followers list
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([currentUserId])
    });
    
    await batch.commit();
  }

  // Unfollow user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Remove targetUserId from current user's following list
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId])
    });
    
    // Remove currentUserId from target user's followers list
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([currentUserId])
    });
    
    await batch.commit();
  }

  // Check if user is following another user
  Future<bool> isFollowing(String followerId, String followedId) async {
    final doc = await _firestore.collection('users').doc(followerId).get();
    final following = List<String>.from(doc.data()?['following'] ?? []);
    return following.contains(followedId);
  }

  // Get followers stream
  Stream<QuerySnapshot> getFollowersStream(String userId) {
    return _firestore
        .collection('users')
        .where('following', arrayContains: userId)
        .snapshots();
  }

  // Get following stream
  Stream<QuerySnapshot> getFollowingStream(String userId) {
    return _firestore
        .collection('users')
        .where('followers', arrayContains: userId)
        .snapshots();
  }

  // Like/Unlike methods
  Future<void> likePost(String userId, String postId) async {
    await _firestore.collection('checkins').doc(postId).update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> unlikePost(String userId, String postId) async {
    await _firestore.collection('checkins').doc(postId).update({
      'likes': FieldValue.arrayRemove([userId])
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
        .map((doc) => UserProfile.fromMap({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }
} 