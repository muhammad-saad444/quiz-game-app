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

  AuthController() {
    // Listen to Auth State changes (Persistence)
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await fetchUserData(user.uid);
      } else {
        _userModel = null;
        notifyListeners();
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
  }

  Future<String?> login(String email, String password) async {
    _setLoading(true);
    try {
      // 1. Perform Firebase Authentication
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 2. IMPORTANT: Manually fetch user data immediately
      // This ensures userModel is NOT null when the UI switches
      await fetchUserData(credential.user!.uid);

      // 3. Update the last login timestamp in Firestore
      await _db.collection('users').doc(credential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      // Return user-friendly error messages
      if (e.code == 'user-not-found') return "No friend found with this email.";
      if (e.code == 'wrong-password') return "Oops! That's the wrong secret key.";
      return e.message;
    } catch (e) {
      _setLoading(false);
      return "Something went wrong. Try again!";
    }
  }

  Future<String?> signUp(String email, String password) async {
    _setLoading(true);
    try {
      // 1. Create the user in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim()
      );

      // 2. Send the verification email immediately
      await result.user?.sendEmailVerification();

      // 3. Create the local model and save to Firestore
      _userModel = UserModel(
          uid: result.user!.uid,
          email: email.trim(),
          lastLogin: DateTime.now()
      );

      await _db.collection('users').doc(result.user!.uid).set(_userModel!.toMap());

      // 4. Force a data fetch to ensure the Provider state is fully updated
      await fetchUserData(result.user!.uid);

      _setLoading(false);
      return null; // Success
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

    // 1. Force Firebase to fetch the latest user info from the server
    await _auth.currentUser?.reload();

    // 2. Get the updated user object
    User? user = _auth.currentUser;

    if (user != null && user.emailVerified) {
      // 3. If verified, sync Firestore data
      await fetchUserData(user.uid);
    } else {
      // Optional: Show a snackbar or message if they haven't actually clicked the link yet
      debugPrint("User still not verified.");
    }

    _setLoading(false);
    // This trigger tells AuthWrapper to check the 'emailVerified' status again
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }
}