import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  // ÖNEMLİ: Bu ID'yi Google Cloud Console'dan almanız GEREKİR.
  static const String _webClientId = "706319913643-qirl39a7m16ofbn9eoib1i2dt35mp66s.apps.googleusercontent.com";

  AuthService(this._firebaseAuth) {
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    String? serverClientId;

    if (!kIsWeb) {
      // v7 ve sonrası, mobil platformlar için 'serverClientId' olarak
      // Web Client ID'nin kullanılmasını bekler.
      serverClientId = _webClientId;
    }
    
    // v7'de 'initialize' çağrısı zorunludur
    await _googleSignIn.initialize(
      serverClientId: serverClientId,
      clientId: kIsWeb ? _webClientId : null,
    );
    _isGoogleSignInInitialized = true;
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    try {
      // v7'de 'authenticate' metodu kullanılır
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      if (googleUser == null) {
        return null; // Kullanıcı iptal etti
      }

      // idToken
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // accessToken (v7'de bu şekilde alınır)
      final authClient = googleUser.authorizationClient;
      final authorization = await authClient.authorizationForScopes(['email']);

      if (authorization == null) {
        return null; // Yetki alınamadı
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _createOrUpdateUserInFirestore(userCredential.user!);
      }
      return userCredential;
    } catch (error) {
      debugPrint("Google Sign In Hatası: $error");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  Future<String?> registerWithEmail(String email, String password) async {
    try {
      final userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _createOrUpdateUserInFirestore(userCredential.user!);
      }
      return "Success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return "Success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> _createOrUpdateUserInFirestore(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@').first,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
      });
    }
  }
}