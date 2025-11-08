// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deck_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut metodunuz
  Future<List<Deck>> fetchRecommendedDecks() async {
    try {
      final snapshot = await _firestore.collection('decks').get();
      final decks = snapshot.docs
          .map((doc) => Deck.fromJson(doc.data()))
          .toList();
      return decks;
    } catch (e) {
      print("Firestore'dan deste çekerken hata: $e");
      throw Exception("Önerilen desteler yüklenemedi: $e");
    }
  }

  // --- YENİ EKLENEN METOD ---
  // Sıralamayı (Leaderboard) getirir
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
      print("Sıralama yüklenirken hata: $e");
      throw Exception("Sıralama yüklenemedi: $e");
    }
  }
}