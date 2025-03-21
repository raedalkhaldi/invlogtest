import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invlog_test/services/auth_service.dart';
import 'package:invlog_test/services/profile_service.dart';
import 'package:invlog_test/models/user_profile.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final ProfileService _profileService;
  
  User? _currentUser;
  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;

  AuthProvider(this._authService, this._profileService) {
    _authService.authStateChanges().listen((User? user) {
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
      // 1. Create Firebase Auth user
      final user = await _authService.createUserWithEmailAndPassword(email, password);
      
      if (user != null) {
        // 2. Create user profile in Firestore
        await _profileService.createOrUpdateProfile(
          UserProfile(
            id: user.uid,
            username: username,
            displayName: '',
            bio: '',
            followers: [],
            following: [],
            createdAt: DateTime.now(),
          )
        );
      }
      
      // 3. Update state
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
} 