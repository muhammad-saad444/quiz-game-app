import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Expose the raw Firebase User so your AuthWrapper can listen to verification state explicitly
  User? get firebaseUser => _auth.currentUser;

  AuthController() {
    // Listen to Auth State changes (Handles persistence & token variations)
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          // Force a quick reload to get the freshest data from the server
          await user.reload();

          // Grab the updated user reference after a successful server reload
          User? refreshedUser = _auth.currentUser;

          if (refreshedUser != null && refreshedUser.emailVerified) {
            _isLoading = true;
            notifyListeners();
            await fetchUserData(refreshedUser.uid);
          } else {
            // Keep user model null if they haven't verified their inbox link yet
            _userModel = null;
          }
        } on FirebaseAuthException catch (e) {
          debugPrint("⚠️ Auth stream background reload error code: ${e.code}");

          // 🎯 THE FIX: If the user was deleted from the console, clear the local session cache
          if (e.code == 'user-not-found') {
            debugPrint("Cleaning up corrupted local session cache for deleted user account.");
            await _auth.signOut();
            _userModel = null;
          }
        } catch (e) {
          debugPrint("Generic exception caught on auth state reload hook: $e");
        }
      } else {
        _userModel = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        _userModel = null;
        debugPrint("User data fetching failed: Document does not exist in Firestore.");
      }
      notifyListeners();
    } catch (e) {
      _userModel = null;
      notifyListeners();
      debugPrint("CRITICAL ERROR: Failed to parse UserModel. Details: $e");
    }
  }

  Future<String?> login(String email, String password) async {
    _setLoading(true);
    try {
      String sanitizedEmail = email.trim().toLowerCase();

      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: password.trim(),
      );

      // Explicit verification check gate during manual login attempts
      if (!credential.user!.emailVerified) {
        _setLoading(false);
        await credential.user?.sendEmailVerification();
        return "Please verify your email address first. A new verification link has been sent to your inbox.";
      }

      await fetchUserData(credential.user!.uid);

      if (_userModel == null) {
        _setLoading(false);
        return "Profile data could not be recovered. Please contact support.";
      }

      await _db.collection('users').doc(credential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return "Invalid login credentials. Please check your key or register as a new player.";
      }
      if (e.code == 'wrong-password') return "Oops! That's the wrong secret key.";
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Something went wrong. Try again!";
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    _setLoading(true);
    try {
      String sanitizedEmail = email.trim().toLowerCase();

      // 1. Create the user inside Firebase Authentication
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: sanitizedEmail,
          password: password.trim()
      );

      // 2. Fire off the verification email immediately
      await result.user?.sendEmailVerification();

      // 3. Prepare the database profile structure
      UserModel newPlayer = UserModel(
          uid: result.user!.uid,
          email: sanitizedEmail,
          name: name.trim(),
          lastLogin: DateTime.now(),
          currentQuestion: 1,
          totalScore: 0,
          scoreHistory: const {}
      );

      // 4. Save the record to your Firestore database collection
      await _db.collection('users').doc(result.user!.uid).set(newPlayer.toMap());

      // 5. Ensure userModel stays null until email verification completes
      _userModel = null;

      _setLoading(false);
      notifyListeners(); // Force stream dispatch to update AuthWrapper state
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      if (e.code == 'email-already-in-use') return "This email is already registered.";
      if (e.code == 'weak-password') return "The secret key is too short!";
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Something went wrong. Let's try again!";
    }
  }

  Future<void> checkEmailVerified() async {
    _setLoading(true);

    // Force Firebase Auth to pull the absolute freshest metadata from the server
    await _auth.currentUser?.reload();
    User? user = _auth.currentUser;

    if (user != null && user.emailVerified) {
      // Once verified, download their Firestore user profile configuration
      await fetchUserData(user.uid);
    } else {
      debugPrint("User clicked verification check, but status is still unverified.");
    }

    _setLoading(false);
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }
}