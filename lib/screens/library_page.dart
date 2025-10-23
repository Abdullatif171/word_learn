import 'package:flutter/material.dart';
import '../models/deck_model.dart';
import '../services/deck_service.dart';
import '../services/firebase_service.dart';
import '../services/save_service.dart';
import 'flashcard_page.dart';

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
  Set<String> _learnedWordsSet = {};
  final Map<String, double> _progressCache = {};
  final Map<String, bool> _loadingState = {}; // İndirme/Silme durumları için

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingState.clear();
    });

    try {
      // 1. Global ilerlemeyi çek (SaveService'ten)
      final progressData = await SaveService.loadLast();
      _learnedWordsSet = (progressData['learned'] ?? []).map((w) => w.englishWord).toSet();

      // 2. İndirilen desteleri çek (DeckService'ten)
      final downloaded = await _deckService.getDownloadedDecks();
      
      // 3. Önerilen desteleri çek (FirebaseService'ten)
      final recommended = await _firebaseService.fetchRecommendedDecks();

      // 4. İndirilenler için ilerlemeyi hesapla
      await _updateProgressForDecks(downloaded);

      if (!mounted) return;
      setState(() {
        _downloadedDecks = downloaded;
        _recommendedDecks = recommended;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kütüphane yüklenemedi: $e")),
      );
      setState(() => _isLoading = false);
    }
  }

  // İndirilmiş destelerin ilerlemesini hesaplar
  Future<void> _updateProgressForDecks(List<Deck> decks) async {
    for (final deck in decks) {
      final progress = await _calculateProgress(deck);
      _progressCache[deck.id] = progress;
    }
  }

  Future<double> _calculateProgress(Deck deck) async {
    try {
      // Kelimeleri yerelden yükle
      final words = await _deckService.loadDeckFromLocal(deck.id);
      if (words.isEmpty) return 0.0;
      
      int learnedCount = 0;
      for (final word in words) {
        if (_learnedWordsSet.contains(word.englishWord)) {
          learnedCount++;
        }
      }
      return learnedCount / words.length;
    } catch (e) {
      return 0.0;
    }
  }

  void _onDeckTapped(Deck deck) async {
    try {
      // Desteyi yerel depodan yükle
      final words = await _deckService.loadDeckFromLocal(deck.id);
      if (!mounted) return;
      // FlashcardPage'e git
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardPage(words: words),
        ),
      );
      // Geri dönüldüğünde ilerlemeyi ve listeyi yenile
      _loadLibraryData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${deck.name} destesi açılamadı: $e")),
      );
    }
  }

  void _onDownloadTapped(Deck deck) async {
    if (_loadingState[deck.id] == true) return; // Zaten işlemde
    
    setState(() => _loadingState[deck.id] = true);
    try {
      await _deckService.downloadDeck(deck);
      await _loadLibraryData(); // Listeyi ve ilerlemeyi yenile
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${deck.name} indirilemedi: $e")),
      );
    } finally {
      setState(() => _loadingState[deck.id] = false);
    }
  }

  void _onDeleteTapped(Deck deck) async {
    if (_loadingState[deck.id] == true) return; // Zaten işlemde

    setState(() => _loadingState[deck.id] = true);
    try {
      await _deckService.deleteDeck(deck.id);
      _progressCache.remove(deck.id); // İlerleme önbelleğini temizle
      await _loadLibraryData(); // Listeyi yenile
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${deck.name} silinemedi: $e")),
      );
    } finally {
      setState(() => _loadingState[deck.id] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Kütüphane'), // Başlık güncellendi
        centerTitle: true,
        elevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLibraryData,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLibraryData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // kitaplığım Bölümü
                    _buildDeckSectionTitle("kitaplığım"),
                    _buildDeckListView(
                      decks: _downloadedDecks,
                      isDownloadedSection: true,
                    ),
                    const SizedBox(height: 20),
                    // Önerilenler Bölümü
                    _buildDeckSectionTitle("Önerilenler"),
                    _buildDeckListView(
                      decks: _recommendedDecks,
                      isDownloadedSection: false,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // "kitaplığım" / "Önerilenler" başlığı
  Widget _buildDeckSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // Yatay deste listesi (örnek.png'deki gibi)
  Widget _buildDeckListView({
    required List<Deck> decks,
    required bool isDownloadedSection,
  }) {
    if (decks.isEmpty && isDownloadedSection) {
      return Container(
        height: 100, // Boş alan yüksekliği
        alignment: Alignment.center,
        child: const Text(
          "Henüz indirilmiş desteniz yok.\n'Önerilenler' bölümünden indirebilirsiniz.",
          textAlign: TextAlign.center,
        ),
      );
    }
    
    if (decks.isEmpty && !isDownloadedSection) {
      return Container(
        height: 100, // Boş alan yüksekliği
        alignment: Alignment.center,
        child: const Text("Yeni deste bulunamadı.", textAlign: TextAlign.center),
      );
    }
    
    // Önerilenler listesini filtrele (zaten indirilmiş olanları gösterme)
    final List<Deck> filteredDecks;
    if (!isDownloadedSection) {
      final downloadedIds = _downloadedDecks.map((d) => d.id).toSet();
      filteredDecks = decks.where((deck) => !downloadedIds.contains(deck.id)).toList();
    } else {
      filteredDecks = decks;
    }

    if (filteredDecks.isEmpty && !isDownloadedSection) {
       return Container(
        height: 100, // Boş alan yüksekliği
        alignment: Alignment.center,
        child: const Text("Tüm önerilen desteler indirilmiş.", textAlign: TextAlign.center),
      );
    }

    return SizedBox(
      height: 200, // Kart yüksekliği
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: filteredDecks.length,
        itemBuilder: (context, index) {
          final deck = filteredDecks[index];
          return _buildDeckCard(deck, isDownloaded: isDownloadedSection);
        },
      ),
    );
  }

  // örnek.png'deki kare kart
  Widget _buildDeckCard(Deck deck, {required bool isDownloaded}) {
    // isDownloaded parametresini doğrudan kullan
    final isLoading = _loadingState[deck.id] ?? false;
    final progress = _progressCache[deck.id] ?? 0.0;

    return GestureDetector(
      onTap: isDownloaded ? () => _onDeckTapped(deck) : null,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(right: 12.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDownloaded ? Colors.blue.shade50 : Colors.grey.shade200,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve İkon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      deck.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (isDownloaded)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () => _onDeleteTapped(deck),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.download, color: Colors.blueAccent, size: 20),
                      onPressed: () => _onDownloadTapped(deck),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Açıklama
              Text(
                deck.description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Kelime Sayısı
              Text(
                "${deck.wordCount} kelime",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              // İlerleme Çubuğu (sadece indirilmişse)
              if (isDownloaded)
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                )
              else
                // İndirilmemişse yer tutucu
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              if (isDownloaded)
                 Padding(
                   padding: const EdgeInsets.only(top: 2.0),
                   child: Text(
                    "%${(progress * 100).toStringAsFixed(0)} tamamlandı",
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                 ),
                 ),
            ],
          ),
        ),
      ),
    );
  }

  // Sayfa değiştirildiğinde state'in korunması için
  @override
  bool get wantKeepAlive => true;
}