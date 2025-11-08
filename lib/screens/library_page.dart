// lib/screens/library_page.dart
import 'package:flutter/material.dart';
import 'package:word_learn/models/deck_model.dart';
import 'package:word_learn/models/word_card.dart'; // WordCard modelini import et
import 'package:word_learn/screens/study_session_page.dart';
import 'package:word_learn/services/deck_service.dart';
import 'package:word_learn/services/firebase_service.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with AutomaticKeepAliveClientMixin {
  final DeckService _deckService = DeckService();
  final FirebaseService _firebaseService = FirebaseService();

  List<Deck> _downloadedDecks = [];
  List<Deck> _recommendedDecks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllDecks();
  }

  Future<void> _loadAllDecks() async {
    setState(() { _isLoading = true; });
    try {
      final downloaded = await _deckService.getDownloadedDecks();
      final recommended = await _firebaseService.fetchRecommendedDecks();
      setState(() {
        _downloadedDecks = downloaded;
        _recommendedDecks = recommended;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Desteler yüklenemedi: $e")),
        );
      }
    }
  }

  // --- HATA DÜZELTMESİ (loadDeckWords -> loadDeckFromLocal) ---
  void _startStudy(Deck deck) async {
    // TODO: Bir yükleme göstergesi eklenebilir
    try {
      // 1. Kelimeleri servisten yükle (Doğru metot adı kullanıldı)
      List<WordCard> words = await _deckService.loadDeckFromLocal(deck.id);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            // 2. StudySessionPage'e hem deste (meta veri) hem de kelimeleri (içerik) gönder
            builder: (context) => StudySessionPage(deck: deck, words: words),
          ),
        ).then((_) => _loadAllDecks());
      }
    } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Deste kelimeleri yüklenemedi: $e")),
           );
        }
    }
  }
  // --- HATA DÜZELTMESİ SONU ---

  void _deleteDeck(Deck deck) async {
     await _deckService.deleteDeck(deck.id);
     _loadAllDecks(); // Listeyi yenile
  }

  void _downloadDeck(Deck deck) async {
    await _deckService.downloadDeck(deck);
    _loadAllDecks(); // Listeyi yenile
  }

  bool _isDownloaded(Deck deck) {
    return _downloadedDecks.any((d) => d.id == deck.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kütüphane"),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.primary))
          : RefreshIndicator(
              color: colorScheme.primary,
              onRefresh: _loadAllDecks,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildDownloadedDecks(context),
                  const SizedBox(height: 24),
                  _buildRecommendedDecks(context),
                ],
              ),
            ),
    );
  }

  // İndirilen Desteler (Modelinize göre 'name' ve 'wordCount' kullanır)
  Widget _buildDownloadedDecks(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (_downloadedDecks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Henüz bir deste indirmediniz. Aşağıdan bir deste seçin.",
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Destelerim",
          style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
        ),
        const SizedBox(height: 10),
        ..._downloadedDecks.map((deck) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _startStudy(deck),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.layers, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(deck.name, style: textTheme.titleLarge),
                          Text(
                            "${deck.wordCount} kelime",
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: colorScheme.error),
                      onPressed: () => _deleteDeck(deck),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // Önerilen Desteler (Modelinize göre 'name' kullanır)
  Widget _buildRecommendedDecks(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Önerilenler",
          style:
              textTheme.headlineSmall?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 10),
        ..._recommendedDecks.map((deck) {
          final bool isDownloaded = _isDownloaded(deck);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.recommend, color: colorScheme.secondary),
              title: Text(deck.name, style: textTheme.titleMedium),
              subtitle: Text(deck.description,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
              trailing: isDownloaded
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : IconButton(
                      icon: Icon(Icons.download_for_offline_outlined,
                          color: colorScheme.primary), // Pirinç rengi
                      onPressed: () => _downloadDeck(deck),
                    ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}