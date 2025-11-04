// screens/library_page.dart
import 'package:flutter/material.dart';
import 'package:word_learn/screens/home_page.dart'; // YENİ EKLENDİ (Puan yenileme için)
import 'package:word_learn/screens/study_session_page.dart'; // YENİ EKLENDİ
import '../models/deck_model.dart';
// import '../models/word_card.dart'; // Bu dosyada artık doğrudan kullanılmıyor
import '../services/deck_service.dart';
import '../services/firebase_service.dart';
// import '../services/save_service.dart'; // Artık bu sayfada kullanılmıyor
// import 'flashcard_page.dart'; // Artık kullanılmıyor

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with AutomaticKeepAliveClientMixin {
  // Servisleri başlat
  final FirebaseService _firebaseService = FirebaseService();
  final DeckService _deckService = DeckService();

  // Durum listeleri
  List<Deck> _downloadedDecks = [];
  List<Deck> _recommendedDecks = [];
  final Map<String, double> _progressCache = {};
  final Map<String, bool> _loadingState = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    setState(() => _isLoading = true);

    try {
      // 1. İndirilen desteleri al
      _downloadedDecks = await _deckService.getDownloadedDecks();

      // 2. Önerilen desteleri al (Firebase'den)
      _recommendedDecks = await _firebaseService.fetchRecommendedDecks();

      // 3. İlerleme hesaplamalarını yap (paralel olarak)
      _progressCache.clear();
      final progressFutures = _downloadedDecks.map((deck) async {
        final progress = await _calculateDeckProgress(deck.id);
        return {deck.id: progress};
      }).toList();

      final results = await Future.wait(progressFutures);
      for (var res in results) {
        _progressCache.addAll(res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veri yüklenirken hata: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // YENİ METOT: Bir destenin ilerlemesini (öğrenilen/toplam) hesaplar
  Future<double> _calculateDeckProgress(String deckId) async {
    try {
      final words = await _deckService.loadDeckFromLocal(deckId);
      if (words.isEmpty) return 0.0;

      // Öğrenilmiş sayılan kelimeler (SRS seviyesi 0'dan büyük olanlar)
      final learnedCount =
          words.where((w) => w.reviewIntervalDays > 0).length;
      return learnedCount / words.length;
    } catch (e) {
      return 0.0;
    }
  }

  // Deste indirme metodu
  Future<void> _downloadDeck(Deck deck) async {
    setState(() => _loadingState[deck.id] = true);
    try {
      await _deckService.downloadDeck(deck);
      // İndirme sonrası kütüphaneyi yenile
      await _loadLibraryData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${deck.name} indirilemedi: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingState.remove(deck.id));
      }
    }
  }

  // Deste silme metodu
  Future<void> _deleteDeck(Deck deck) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${deck.name} Silinsin mi?"),
        content: const Text(
            "Bu desteyi ve ilerlemenizi silmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loadingState[deck.id] = true);
      try {
        await _deckService.deleteDeck(deck.id);
        // Silme sonrası kütüphaneyi yenile
        await _loadLibraryData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${deck.name} silinemedi: $e")),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _loadingState.remove(deck.id));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kütüphane"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLibraryData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionTitle(
                      "📚 İndirilen Destelerim (${_downloadedDecks.length})"),
                  _buildDownloadedDecks(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                      "✨ Önerilen Desteler (${_recommendedDecks.length})"),
                  _buildRecommendedDecks(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // İndirilen desteleri listeler
  Widget _buildDownloadedDecks() {
    if (_downloadedDecks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child:
              Text("Henüz bir deste indirmediniz. Aşağıdan bir deste seçin."),
        ),
      );
    }
    return Column(
      children: _downloadedDecks.map((deck) {
        final progress = _progressCache[deck.id] ?? 0.0;
        final isLoading = _loadingState[deck.id] ?? false;
        return _buildDeckCard(
          deck: deck,
          isDownloaded: true,
          progress: progress,
          isLoading: isLoading,
        );
      }).toList(),
    );
  }

  // Önerilen desteleri listeler
  Widget _buildRecommendedDecks() {
    final downloadedIds = _downloadedDecks.map((d) => d.id).toSet();
    final decksToShow = _recommendedDecks
        .where((d) => !downloadedIds.contains(d.id))
        .toList();

    if (decksToShow.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Tüm önerilen desteleri indirmişsiniz!"),
        ),
      );
    }

    return Column(
      children: decksToShow.map((deck) {
        final isLoading = _loadingState[deck.id] ?? false;
        return _buildDeckCard(
          deck: deck,
          isDownloaded: false,
          progress: 0.0,
          isLoading: isLoading,
        );
      }).toList(),
    );
  }

  // Tek bir deste kartı widget'ı
  Widget _buildDeckCard({
    required Deck deck,
    required bool isDownloaded,
    required double progress,
    required bool isLoading,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        
        onTap: () {
          if (isLoading) return;
          if (!isDownloaded) return; 

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudySessionPage(deck: deck),
            ),
          ).then((_) {
            // Oturum bittiğinde (pop ile geri dönüldüğünde)
            
            // 1. Kütüphane sayfasını (ve ilerleme çubuklarını) yenile
            _loadLibraryData();

            // 2. Ana Sayfa'yı (ve toplam puanı) yenile
            // HATA DÜZELTMESİ: _HomePageState -> HomePageState
            // HATA DÜZELTMESİ: _onTap -> publicOnTap
            final homeState = context.findAncestorStateOfType<HomePageState>();
            if (homeState != null) {
              homeState.publicOnTap(0); // Ana Sayfaya (index 0) git
            }
          });
        },

        onLongPress: isDownloaded
            ? () => _deleteDeck(deck)
            : null, 
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                isDownloaded ? Icons.folder_open : Icons.cloud_download_outlined,
                color: Colors.blueAccent,
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      deck.description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildDeckActionButton(
                deck: deck,
                isDownloaded: isDownloaded,
                isLoading: isLoading,
                progress: progress,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeckActionButton({
    required Deck deck,
    required bool isDownloaded,
    required bool isLoading,
    required double progress,
  }) {
    if (isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isDownloaded) {
      return Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
                Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${(progress * 100).toStringAsFixed(0)}%",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.download),
              color: Colors.blueAccent,
              onPressed: () => _downloadDeck(deck),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${deck.wordCount} kelime",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
}