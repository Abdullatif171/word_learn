// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- YENİ IMPORT
import '../models/deck_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // <-- YENİ INSTANCE

  // Mevcut metodunuz
  Future<List<Deck>> fetchRecommendedDecks() async {
    try {
      final snapshot = await _firestore.collection('decks').get();
      final decks = snapshot.docs
          .map((doc) => Deck.fromJson(doc.data()))
          .toList();
      return decks;
    } catch (e) {
      throw Exception("Önerilen desteler yüklenemedi: $e");
    }
  }

  // Mevcut metodunuz
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      // 'users' koleksiyonundan verileri 'totalScore' alanına göre
      // azalan sırada (en yüksekten düşüğe) sırala ve ilk 50 kişiyi al.
      final snapshot = await _firestore
          .collection('users')
          .orderBy('totalScore', descending: true)
          .limit(50)
          .get();

      // Doküman verilerini bir liste olarak döndür
      return snapshot.docs.map((doc) => doc.data()).toList();
      
    } catch (e) {
      throw Exception("Sıralama yüklenemedi: $e");
    }
  }

  // --- YENİ EKLENEN METOT (Puanı Firebase'de Güncelle) ---
  Future<void> updateUserScoreInFirestore(int scoreToAdd) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      // Kullanıcı giriş yapmamış, güncelleme yapılamaz
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      
      // FieldValue.increment kullanarak mevcut skora ekleme yap (en güvenli yöntem)
      await userRef.update({
        'totalScore': FieldValue.increment(scoreToAdd),
      });
    } catch (e) {
      // auth_service zaten kullanıcıyı oluşturmuş olmalı, 
      // ama bir hata olursa (örn. doküman silinirse) burada hata alırız.
      throw Exception("Puan sunucuda güncellenemedi: $e");
    }
  }
}