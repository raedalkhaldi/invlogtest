import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checkin_model.dart';
import '../models/comment_model.dart';
import '../services/checkin_service.dart';

class CheckInProvider extends ChangeNotifier {
  final CheckInService _checkInService = CheckInService();
  List<CheckInModel> _checkIns = [];
  final Map<String, List<CommentModel>> _comments = {};
  bool _isLoading = false;
  String? _error;
  String? _selectedRestaurant;
  File? _selectedPhoto;
  String? _caption;

  List<CheckInModel> get checkIns => _checkIns;
  Map<String, List<CommentModel>> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedRestaurant => _selectedRestaurant;
  File? get selectedPhoto => _selectedPhoto;
  String? get caption => _caption;

  void setSelectedRestaurant(String? restaurant) {
    _selectedRestaurant = restaurant;
    notifyListeners();
  }

  void setSelectedPhoto(File? photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }

  void setCaption(String? caption) {
    _caption = caption;
    notifyListeners();
  }

  Future<void> createCheckIn(String userId, GeoPoint location, String username, String? displayName) async {
    if (_selectedRestaurant == null) {
      _error = 'Please select a restaurant';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _checkInService.createCheckIn(
        userId: userId,
        username: username,
        displayName: displayName,
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

  // Load comments for a check-in
  Future<void> loadComments(String checkInId) async {
    try {
      _checkInService.getCheckInComments(checkInId).listen(
        (comments) {
          _comments[checkInId] = comments;
          notifyListeners();
        },
        onError: (error) {
          _error = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Add a comment to a check-in
  Future<void> addComment(String checkInId, String userId, String text) async {
    try {
      await _checkInService.addComment(
        checkInId: checkInId,
        userId: userId,
        text: text,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String checkInId) async {
    try {
      await _checkInService.deleteComment(commentId, checkInId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Get comments for a check-in
  List<CommentModel> getCommentsForCheckIn(String checkInId) {
    return _comments[checkInId] ?? [];
  }
} 