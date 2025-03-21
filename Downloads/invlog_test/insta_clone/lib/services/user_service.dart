import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get user profile
  Stream<UserModel?> getUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Update user profile
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? bio,
    File? photoFile,
  }) async {
    try {
      String? photoUrl;
      if (photoFile != null) {
        // Upload new profile photo
        final ref = _storage.ref().child('profile_photos/$userId');
        await ref.putFile(photoFile);
        photoUrl = await ref.getDownloadURL();
      }

      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Follow a user
  Future<void> followUser(String followerId, String followedId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Add to follower's following list
        transaction.update(
          _firestore.collection('users').doc(followerId),
          {'following': FieldValue.arrayUnion([followedId])},
        );

        // Add to followed user's followers list
        transaction.update(
          _firestore.collection('users').doc(followedId),
          {'followers': FieldValue.arrayUnion([followerId])},
        );
      });
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String followerId, String followedId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Remove from follower's following list
        transaction.update(
          _firestore.collection('users').doc(followerId),
          {'following': FieldValue.arrayRemove([followedId])},
        );

        // Remove from followed user's followers list
        transaction.update(
          _firestore.collection('users').doc(followedId),
          {'followers': FieldValue.arrayRemove([followerId])},
        );
      });
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow;
    }
  }

  // Search users
  Stream<List<UserModel>> searchUsers(String query) {
    if (query.isEmpty) return Stream.value([]);

    return _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    });
  }
} 