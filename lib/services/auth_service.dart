// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:word_learn/firebase_options.dart'; // ID'yi almak için
import 'package:flutter/foundation.dart'; // Platform kontrolü için

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  AuthService(this._firebaseAuth) {
    _initializeGoogleSignIn();
  }

  // Adım 2: Asenkron başlatma (HATA DÜZELTİLDİ)
  Future<void> _initializeGoogleSignIn() async {
    try {
      // Android ve iOS platformları için 'serverClientId' olarak 
      // 'iosClientId' kullanılır. Bu, FlutterFire'ın yapılandırma şeklidir.
      // Web platformu farklı bir 'clientId' kullanır ancak şu anki hatanız
      // mobil platformla ilgilidir.
      
      String? serverClientId;
      
      if (!kIsWeb) {
         // Android ve iOS için 'iosClientId' kullanılır.
        serverClientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
      }
      // Not: Eğer web'i de destekleyecekseniz, Google Cloud Console'dan
      // aldığınız Web Client ID'sini buraya manuel eklemeniz gerekebilir.
      // Şimdilik mobil hatasını çözüyoruz.

      await _googleSignIn.initialize(
        serverClientId: serverClientId, // Düzeltilmiş ID'yi buraya iletiyoruz
      );
      _isGoogleSignInInitialized = true;
    } catch (e) {
      print('Failed to initialize Google Sign-In: $e');
    }
  }

  // Adım 2: Başlatmayı kontrol et
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  // Stream ve anlık kullanıcı için
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;


  // Adım 8: Firebase Entegrasyonu
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    try {
      // Adım 3: 'authenticate' kullan
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      // Kullanıcı iptal ederse googleUser null gelebilir
      if (googleUser == null) {
        print("Google Sign In iptal edildi.");
        return null;
      }

      // Adım 5: Senkron 'authentication' al (idToken için)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Adım 6: 'authorizationClient' al (accessToken için)
      final authClient = googleUser.authorizationClient;
      final authorization = await authClient.authorizationForScopes(['email']);

      if (authorization == null) {
        print("Authorization alınamadı.");
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      // Firestore'a kaydet
      if (userCredential.user != null) {
        await _createOrUpdateUserInFirestore(userCredential.user!);
      }
      return userCredential;

    } on GoogleSignInException catch (e) {
      print('Google Sign In error: code: ${e.code.name} description:${e.description}');
      return null;
    } catch (error) {
      print('Unexpected Google Sign-In error: $error');
      return null;
    }
  }

  // Çıkış Yap
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
  
  // --- DİĞER METOTLARINIZ (Değişiklik Gerekmiyor) ---

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