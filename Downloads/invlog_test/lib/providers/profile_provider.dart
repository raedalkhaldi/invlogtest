import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;
  UserProfile? _userProfile;
  final List<String> _followers = [];
  final List<String> _following = [];

  UserProfile? get userProfile => _userProfile;
  List<String> get followers => _followers;
  List<String> get following => _following;

  ProfileProvider(this._profileService);

  Future<UserProfile> getUserProfile(String userId) async {
    _userProfile = await _profileService.getUserProfile(userId);
    notifyListeners();
    return _userProfile!;
  }

  Future<void> updateProfile(String userId, {
    String? displayName,
    String? bio,
    String? profileImageUrl,
  }) async {
    await _profileService.updateProfile(
      userId,
      displayName: displayName,
      bio: bio,
      profileImageUrl: profileImageUrl,
    );
    _userProfile = await _profileService.getUserProfile(userId);
    notifyListeners();
  }

  Future<void> followUser(String userId) async {
    if (_userProfile == null) return;
    await _profileService.followUser(_userProfile!.id, userId);
    _userProfile = await _profileService.getUserProfile(_userProfile!.id);
    notifyListeners();
  }

  Future<void> unfollowUser(String userId) async {
    if (_userProfile == null) return;
    await _profileService.unfollowUser(_userProfile!.id, userId);
    _userProfile = await _profileService.getUserProfile(_userProfile!.id);
    notifyListeners();
  }
} 