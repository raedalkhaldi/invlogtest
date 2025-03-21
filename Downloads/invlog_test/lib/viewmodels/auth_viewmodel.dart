import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  AuthViewModel() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      _isLoggedIn = user != null;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> signUp(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create initial user profile
      if (userCredential.user != null) {
        final profile = UserProfile(
          id: userCredential.user!.uid,
          username: '', // User will set this later
          displayName: '',
          bio: '',
          followers: [],
          following: [],
          createdAt: DateTime.now(),
        );
        await _profileService.createOrUpdateProfile(profile);
      }

      _isLoggedIn = true;
      _error = null;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'An error occurred during sign up';
      _isLoggedIn = false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isLoggedIn = true;
      _error = null;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'An error occurred during sign in';
      _isLoggedIn = false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _isLoggedIn = false;
    } catch (e) {
      rethrow;
    }
    notifyListeners();
  }
} 