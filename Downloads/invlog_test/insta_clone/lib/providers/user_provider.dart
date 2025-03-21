import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  UserModel? _currentUser;
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  File? _selectedPhoto;
  String? _username;
  String? _bio;

  UserModel? get currentUser => _currentUser;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  File? get selectedPhoto => _selectedPhoto;
  String? get username => _username;
  String? get bio => _bio;

  void setSelectedPhoto(File? photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }

  void setUsername(String? username) {
    _username = username;
    notifyListeners();
  }

  void setBio(String? bio) {
    _bio = bio;
    notifyListeners();
  }

  // Load user profile
  Future<void> loadUserProfile(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _userService.getUserProfile(userId).listen(
        (user) {
          _currentUser = user;
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

  // Update user profile
  Future<void> updateProfile(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _userService.updateProfile(
        userId: userId,
        username: _username,
        bio: _bio,
        photoFile: _selectedPhoto,
      );

      // Reset form
      _selectedPhoto = null;
      _username = null;
      _bio = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Follow a user
  Future<void> followUser(String followerId, String followedId) async {
    try {
      await _userService.followUser(followerId, followedId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String followerId, String followedId) async {
    try {
      await _userService.unfollowUser(followerId, followedId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Search users
  Future<void> searchUsers(String query) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _userService.searchUsers(query).listen(
        (users) {
          _searchResults = users;
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

  // Check if current user is following another user
  bool isFollowing(String userId) {
    return _currentUser?.following.contains(userId) ?? false;
  }
} 