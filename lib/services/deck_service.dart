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

  // Simüle edilmiş veritabanı kaldırıldı.

  // Bir destenin .json dosyasının yerel yolunu döndürür
  Future<String> _getLocalPath(String deckId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/deck_$deckId.json';
  }

  // Desteyi indir ve yerel olarak kaydet
  Future<void> downloadDeck(Deck deck) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. "Remote" veriyi HTTP ile indir (Firebase Storage'dan)
    final response = await http.get(Uri.parse(deck.downloadUrl));
    
    if (response.statusCode == 200) {
      // 2. Veriyi yerel depoya (cihazın dosyasına) yaz
      final path = await _getLocalPath(deck.id);
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes); // JSON içeriğini yaz

      // 3. Manifest'i güncelle (indirilenler listesi)
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

    // 1. Yerel dosyayı sil
    try {
      final path = await _getLocalPath(deckId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Yerel dosya silinirken hata: $e");
    }

    // 2. Manifest'ten çıkar
    final downloaded = await getDownloadedDecks();
    downloaded.removeWhere((d) => d.id == deckId);
    final manifestString = jsonEncode(downloaded.map((d) => d.toJson()).toList());
    await prefs.setString(_manifestKey, manifestString);
  }

  // Bu destenin indirilip indirilmediğini kontrol et
  Future<bool> isDeckDownloaded(String deckId) async {
    final path = await _getLocalPath(deckId);
    final file = File(path);
    return await file.exists();
  }

  // İndirilen tüm destelerin listesini (meta-data) manifest'ten oku
  Future<List<Deck>> getDownloadedDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final manifestString = prefs.getString(_manifestKey);
    if (manifestString == null) return [];

    final List<dynamic> jsonList = jsonDecode(manifestString);
    return jsonList.map((json) => Deck.fromJson(json)).toList();
  }

  // İndirilmiş bir destenin kelimelerini yerel dosyadan oku
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
      // Eğer dosya bozuksa veya okunamıyorsa, manifest'ten sil
      await deleteDeck(deckId);
      throw Exception("Deste yüklenemedi ve kaldırıldı.");
    }
  }
}