// services/deck_service.dart
import 'dart:convert';
import 'dart:io'; // Dosya işlemleri için
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // HTTP istekleri için
import 'package:path_provider/path_provider.dart'; // Yerel yolu bulmak için
import '../models/deck_model.dart';
import '../models/word_card.dart';

class DeckService {
  static const String _manifestKey = "downloaded_decks_manifest";
  static const String _userScoreKey = "user_global_score"; // YENİ EKLENDİ

  // ----- SRS Mantığı (flashcard_page.dart dosyasından taşındı) -----
  // Basitleştirilmiş SRS aralıkları (gün cinsinden)
  final List<int> _srsIntervals = [1, 3, 7, 14, 30, 90, 180];

  WordCard _updateSrs(WordCard word) {
    final currentLevel = _srsIntervals.indexOf(word.reviewIntervalDays);
    final nextLevelIndex = (currentLevel + 1).clamp(0, _srsIntervals.length - 1);
    final nextIntervalDays = _srsIntervals[nextLevelIndex];
    final nextReviewDate = DateTime.now().add(Duration(days: nextIntervalDays));
    return word.copyWith(
      reviewIntervalDays: nextIntervalDays,
      nextReviewTimestamp: nextReviewDate.toIso8601String(),
    );
  }

  WordCard _resetSrs(WordCard word) {
    return word.copyWith(
      reviewIntervalDays: 0, // 0: Yeni kelime olarak başla
      nextReviewTimestamp: null,
    );
  }
  // ----- SRS Mantığı Sonu -----


  // Bir destenin .json dosyasının yerel yolunu döndürür
  Future<String> _getLocalPath(String deckId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/deck_$deckId.json';
  }

  // Desteyi indir ve yerel olarak kaydet
  Future<void> downloadDeck(Deck deck) async {
    final prefs = await SharedPreferences.getInstance();
    final response = await http.get(Uri.parse(deck.downloadUrl));
    
    if (response.statusCode == 200) {
      final path = await _getLocalPath(deck.id);
      final file = File(path);
      
      // YENİ GÜNCELLEME: İndirilen kelimelere SRS alanı ekleniyor
      // Firebase'den gelen JSON'da SRS alanları yoksa, onları ekleyerek kaydet
      final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
      final List<WordCard> words = jsonList.map((e) => WordCard.fromJson(e)).toList();
      final manifestStringData = jsonEncode(words.map((w) => w.toJson()).toList());

      await file.writeAsString(manifestStringData); // JSON içeriğini yaz

      // Manifest'i güncelle (indirilenler listesi)
      final downloaded = await getDownloadedDecks();
      if (!downloaded.any((d) => d.id == deck.id)) {
        downloaded.add(deck);
        final manifestString = jsonEncode(downloaded.map((d) => d.toJson()).toList());
        await prefs.setString(_manifestKey, manifestString);
      }
    } else {
      throw Exception("Deste indirilemedi. Hata kodu: ${response.statusCode}");
    }
  }

  // Desteyi yerel depodan sil
  Future<void> deleteDeck(String deckId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final path = await _getLocalPath(deckId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Yerel dosya silinirken hata: $e");
    }
    final downloaded = await getDownloadedDecks();
    downloaded.removeWhere((d) => d.id == deckId);
    final manifestString = jsonEncode(downloaded.map((d) => d.toJson()).toList());
    await prefs.setString(_manifestKey, manifestString);
  }

  Future<bool> isDeckDownloaded(String deckId) async {
    final path = await _getLocalPath(deckId);
    final file = File(path);
    return await file.exists();
  }

  Future<List<Deck>> getDownloadedDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final manifestString = prefs.getString(_manifestKey);
    if (manifestString == null) return [];
    final List<dynamic> jsonList = jsonDecode(manifestString);
    return jsonList.map((json) => Deck.fromJson(json)).toList();
  }

  Future<List<WordCard>> loadDeckFromLocal(String deckId) async {
    try {
      final path = await _getLocalPath(deckId);
      final file = File(path);
      
      if (!await file.exists()) {
        throw Exception("Yerel deste bulunamadı: $deckId");
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => WordCard.fromJson(json)).toList();

    } catch (e) {
      print("Yerel deste yüklenirken hata: $e");
      await deleteDeck(deckId);
      throw Exception("Deste yüklenemedi ve kaldırıldı.");
    }
  }
  
  // ----- YENİ METOTLAR -----

  // Kullanıcının toplam puanını getir
  Future<int> getUserScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userScoreKey) ?? 0;
  }
  
  // Kullanıcının toplam puanını güncelle
  Future<void> updateUserScore(int scoreToAdd) async {
    final prefs = await SharedPreferences.getInstance();
    int currentScore = prefs.getInt(_userScoreKey) ?? 0;
    await prefs.setInt(_userScoreKey, currentScore + scoreToAdd);
  }
  
  // Çalışma oturumundan sonra kelimelerin ilerlemesini (SRS) güncelle
  Future<void> updateWordsProgress(String deckId, List<WordCard> correct, List<WordCard> incorrect) async {
    // 1. Tüm desteyi yükle
    final List<WordCard> allWords = await loadDeckFromLocal(deckId);

    // 2. Doğru ve yanlış kelimeleri güncelle
    for (var word in correct) {
      final index = allWords.indexWhere((w) => w.englishWord == word.englishWord);
      if (index != -1) {
        allWords[index] = _updateSrs(allWords[index]); // SRS ilerlet
      }
    }
    
    for (var word in incorrect) {
      final index = allWords.indexWhere((w) => w.englishWord == word.englishWord);
      if (index != -1) {
        allWords[index] = _resetSrs(allWords[index]); // SRS sıfırla
      }
    }
    
    // 3. Güncellenmiş listeyi tekrar dosyaya yaz
    final path = await _getLocalPath(deckId);
    final file = File(path);
    final manifestStringData = jsonEncode(allWords.map((w) => w.toJson()).toList());
    await file.writeAsString(manifestStringData);
  }
}