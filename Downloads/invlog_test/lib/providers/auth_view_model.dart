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
          photoUrl: firebaseUser.photoURL,
          isEmailVerified: firebaseUser.emailVerified,
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
          checkIns: [],
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

      print('Starting user registration...'); // Debug log

      // Create user with Firebase
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Firebase Auth user created: ${userCredential.user?.uid}'); // Debug log

      if (userCredential.user != null) {
        // Create user profile in Firestore
        final userProfile = UserProfile(
          id: userCredential.user!.uid,
          username: email.split('@')[0], // Use email prefix as username
          displayName: email.split('@')[0], // Use email prefix as initial display name
          bio: 'Hello! I am using InvLog',
          profileImageUrl: userCredential.user!.photoURL,
          followers: [],
          following: [],
          checkIns: [],
          createdAt: DateTime.now(),
        );
        
        print('Creating user profile in Firestore...'); // Debug log
        await _profileService.createUserProfile(userProfile);
        print('User profile created successfully'); // Debug log

        // Update current user
        _currentUser = User(
          id: userCredential.user!.uid,
          email: email,
          name: email.split('@')[0],
          photoUrl: userCredential.user!.photoURL,
          isEmailVerified: userCredential.user!.emailVerified,
          createdAt: DateTime.now(),
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error during sign up: $e'); // Debug log
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