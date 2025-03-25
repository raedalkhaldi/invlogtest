import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';
import '../services/checkin_service.dart';
import '../services/profile_service.dart';
import '../services/user_service.dart';

class CheckInProvider extends ChangeNotifier {
  final CheckInService _checkInService = CheckInService();
  final ProfileService _profileService = ProfileService();
  final UserService _userService = UserService();
  List<CheckInModel> _checkIns = [];
  final Map<String, List<CommentModel>> _comments = {};
  final Map<String, StreamSubscription<List<CommentModel>>> _commentSubscriptions = {};
  bool _isLoading = false;
  String? _error;
  String? _selectedRestaurant;
  String? _caption;
  File? _selectedPhoto;

  List<CheckInModel> get checkIns => _checkIns;
  Map<String, List<CommentModel>> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedRestaurant => _selectedRestaurant;
  String? get caption => _caption;
  File? get selectedPhoto => _selectedPhoto;

  @override
  void dispose() {
    // Cancel all comment subscriptions
    for (var subscription in _commentSubscriptions.values) {
      subscription.cancel();
    }
    _commentSubscriptions.clear();
    super.dispose();
  }

  void setSelectedRestaurant(String? restaurant) {
    _selectedRestaurant = restaurant;
    notifyListeners();
  }

  void setCaption(String? caption) {
    _caption = caption;
    notifyListeners();
  }

  void setSelectedPhoto(File? photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }

  Future<void> createCheckIn(String userId, GeoPoint location) async {
    if (_selectedRestaurant == null) {
      _error = 'Please select a restaurant';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get user profile to get username
      final userProfile = await _userService.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      await _checkInService.createCheckIn(
        userId: userId,
        username: userProfile.username,
        displayName: userProfile.displayName,
        restaurantName: _selectedRestaurant!,
        location: location,
        caption: _caption,
        photoFile: _selectedPhoto,
      );

      // Reset form
      _selectedRestaurant = null;
      _selectedPhoto = null;
      _caption = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserCheckIns(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _checkInService.getUserCheckIns(userId).listen(
        (checkIns) {
          _checkIns = checkIns;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _error = error.toString();
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> likeCheckIn(String checkInId, String userId) async {
    try {
      await _checkInService.likeCheckIn(checkInId, userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadComments(String checkInId) async {
    try {
      // Cancel existing subscription if any
      await _commentSubscriptions[checkInId]?.cancel();

      print('Loading comments for check-in: $checkInId'); // Debug log

      // Create new subscription
      final subscription = _checkInService.getCheckInComments(checkInId).listen(
        (comments) {
          print('Received ${comments.length} comments for check-in $checkInId'); // Debug log
          _comments[checkInId] = comments;
          notifyListeners();
        },
        onError: (error) {
          print('Error loading comments: $error'); // Debug log
          _error = error.toString();
          notifyListeners();
        },
      );

      _commentSubscriptions[checkInId] = subscription;
    } catch (e) {
      print('Error in loadComments: $e'); // Debug log
      print('Stack trace: ${StackTrace.current}'); // Debug log
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addComment(String checkInId, String userId, String text) async {
    try {
      final userProfile = await _profileService.getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Verify that the user is authenticated
      if (userId.isEmpty) {
        throw Exception('User must be authenticated to comment');
      }

      print('Adding comment with userId: $userId'); // Debug log

      await _checkInService.addComment(
        checkInId: checkInId,
        userId: userId,
        username: userProfile.username,
        displayName: userProfile.displayName,
        text: text,
      );

      // The stream will automatically update the UI
    } catch (e) {
      print('Error in CheckInProvider.addComment: $e'); // Debug log
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId, String checkInId) async {
    try {
      await _checkInService.deleteComment(commentId, checkInId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<CommentModel> getCommentsForCheckIn(String checkInId) {
    final comments = _comments[checkInId] ?? [];
    print('Getting ${comments.length} comments for check-in $checkInId'); // Debug log
    return comments;
  }

  Future<void> deleteCheckIn(String checkInId) async {
    try {
      await _checkInService.deleteCheckIn(checkInId);
      notifyListeners(); // Notify listeners to update the UI
    } catch (e) {
      print('Error in CheckInProvider.deleteCheckIn: $e');
      rethrow;
    }
  }
} 