import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:invlog_test/services/auth_service.dart';
import 'package:invlog_test/services/profile_service.dart';
import 'package:invlog_test/models/user_profile.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final ProfileService _profileService;
  
  firebase_auth.User? _currentUser;
  bool get isAuthenticated => _currentUser != null;
  firebase_auth.User? get currentUser => _currentUser;

  AuthProvider(this._authService, this._profileService) {
    _authService.authStateChanges().listen((firebase_auth.User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      final user = await _authService.signInWithEmailAndPassword(email, password);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    try {
      final user = await _authService.createUserWithEmailAndPassword(email, password);

      if (user != null) {
        final userProfile = UserProfile(
          id: user.uid,
          username: username.toLowerCase(),
          displayName: username,
          bio: 'Hello! I am using InvLog',
          followers: [],
          following: [],
          checkIns: [],
          createdAt: DateTime.now(),
        );

        await _profileService.createUserProfile(userProfile);
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      print('Error during sign up: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
} 