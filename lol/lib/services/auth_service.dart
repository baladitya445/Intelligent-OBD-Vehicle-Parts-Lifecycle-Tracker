import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current app user data
  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // Register with email and password
  Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document in Firestore
        final appUser = AppUser(
          uid: credential.user!.uid,
          email: email,
          name: name,
          role: role,
        );

        await _firestore.collection('users').doc(credential.user!.uid).set(appUser.toMap());

        // Send email verification
        await credential.user!.sendEmailVerification();

        return AuthResult.success(credential.user!);
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Registration failed');
    } catch (e) {
      return AuthResult.failure('Registration failed: $e');
    }

    return AuthResult.failure('Registration failed');
  }

  // Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return AuthResult.success(credential.user!);
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Sign in failed');
    } catch (e) {
      return AuthResult.failure('Sign in failed: $e');
    }

    return AuthResult.failure('Sign in failed');
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null, message: 'Password reset email sent');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Failed to send reset email');
    } catch (e) {
      return AuthResult.failure('Failed to send reset email: $e');
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    required String name,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }

        // Update in Firestore as well
        await _firestore.collection('users').doc(user.uid).update({
          'name': name,
          if (photoURL != null) 'photoURL': photoURL,
        });

        return true;
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
    return false;
  }

  // Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
    } catch (e) {
      print('Error sending email verification: $e');
    }
  }

  // Delete account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        // Delete user document from Firestore
        await _firestore.collection('users').doc(user.uid).delete();

        // Delete the auth account
        await user.delete();

        return AuthResult.success(null, message: 'Account deleted successfully');
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(e.message ?? 'Failed to delete account');
    } catch (e) {
      return AuthResult.failure('Failed to delete account: $e');
    }

    return AuthResult.failure('No user to delete');
  }
}

// Auth result wrapper
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? message;
  final String? error;

  AuthResult.success(this.user, {this.message})
      : isSuccess = true, error = null;

  AuthResult.failure(this.error)
      : isSuccess = false, user = null, message = null;
}
