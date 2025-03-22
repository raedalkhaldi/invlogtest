import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/checkin_model.dart';
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
      'createdAt': profile.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
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
    return _firestore
        .collection('checkins')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckInModel.fromFirestore(doc))
            .toList());
  }

  // Get user's liked posts stream
  Stream<List<CheckInModel>> getLikedPostsStream(String userId) {
    print('Getting liked posts for user: $userId'); // Debug log
    return _firestore
        .collection('checkins')
        .where('likes', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          print('Received ${snapshot.docs.length} liked posts'); // Debug log
          return snapshot.docs
              .map((doc) {
                print('Processing liked post document: ${doc.data()}'); // Debug log
                return CheckInModel.fromFirestore(doc);
              })
              .toList();
        });
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
            .map((doc) => UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get following stream
  Stream<List<UserProfile>> getFollowingStream(String userId) {
    return _firestore
        .collection('users')
        .where('followers', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
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
} 