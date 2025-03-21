import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class AuthViewModel extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthViewModel() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _currentUser = User(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? 'User',
          createdAt: DateTime.now(),
        );
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Sign in with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create or update user profile in Firestore
        final userProfile = UserProfile(
          id: userCredential.user!.uid,
          username: email.split('@')[0], // Use email prefix as username
          displayName: userCredential.user!.displayName ?? 'User',
          bio: 'Hello! I am using InvLog',
          profileImageUrl: userCredential.user!.photoURL,
          followers: [],
          following: [],
          createdAt: DateTime.now(),
        );
        
        await _profileService.createOrUpdateProfile(userProfile);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create user with Firebase
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user profile in Firestore
        final userProfile = UserProfile(
          id: userCredential.user!.uid,
          username: email.split('@')[0], // Use email prefix as username
          displayName: userCredential.user!.displayName ?? 'User',
          bio: 'Hello! I am using InvLog',
          profileImageUrl: userCredential.user!.photoURL,
          followers: [],
          following: [],
          createdAt: DateTime.now(),
        );
        
        await _profileService.createOrUpdateProfile(userProfile);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
} 