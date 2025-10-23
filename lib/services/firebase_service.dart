// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deck_model.dart';

class FirebaseService {
  // Firebase Firestore örneğini al
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gerçek Firebase Firestore çağrısı
  Future<List<Deck>> fetchRecommendedDecks() async {
    try {
      // 'decks' koleksiyonundan tüm dokümanları çek
      final snapshot = await _firestore.collection('decks').get();

      // Gelen dokümanları Deck modeline dönüştür
      final decks = snapshot.docs
          .map((doc) => Deck.fromJson(doc.data()))
          .toList();
          
      return decks;

    } catch (e) {
      // Hata olursa konsola yazdır ve boş liste dön
      print("Firestore'dan deste çekerken hata: $e");
      throw Exception("Önerilen desteler yüklenemedi: $e");
    }
  }
}