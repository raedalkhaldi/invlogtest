import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Email & Password Sign Up
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final user = UserModel(
          uid: result.user!.uid,
          email: email,
          username: username,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(user.toMap());

        return user;
      }
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
    return null;
  }

  // Email & Password Sign In
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get();
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
    return null;
  }

  // Google Sign In
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);

      if (result.user != null) {
        // Check if user exists in Firestore
        final doc = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get();

        if (!doc.exists) {
          final user = UserModel(
            uid: result.user!.uid,
            email: result.user!.email!,
            username: result.user!.displayName ?? 'User',
            photoUrl: result.user!.photoURL,
            createdAt: DateTime.now(),
          );

          await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .set(user.toMap());

          return user;
        } else {
          return UserModel.fromFirestore(doc);
        }
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
    return null;
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
} 