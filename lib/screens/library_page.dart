// screens/categories_page.dart
import 'package:flutter/material.dart';
import '../models/deck_model.dart';
import '../models/word_card.dart'; // Yeni eklendi
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
  Set<String> _learnedWordsSet = {}; // Global öğrenilmiş kelimeler
  final Map<String, double> _progressCache = {};
  final Map<String, bool> _loadingState = {};

  // Yeni durumlar (Kategoriye göre gruplanmış kelimeler)
  Map<String, List<WordCard>> _learnedWordsByCategory = {};
  Map<String, List<WordCard>> _unlearnedWordsByCategory = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  // Helper method: Groups a list of WordCards by their category
  Map<String, List<WordCard>> _groupWordsByCategory(List<WordCard> words) {
    final Map<String, List<WordCard>> grouped = {};
    for (var word in words) {
      grouped.putIfAbsent(word.category, () => []).add(word);
    }
    // Öğrenilen kelimeleri SRS tekrar tarihine göre sırala
    grouped.forEach((key, value) {
        value.sort((a, b) => 
            (a.nextReviewTimestamp ?? DateTime.now().toIso8601String())
            .compareTo(b.nextReviewTimestamp ?? DateTime.now().toIso8601String()));
    });
    return grouped;
  }

  Future<void> _loadLibraryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingState.clear();
      _learnedWordsByCategory.clear();
      _unlearnedWordsByCategory.clear();
    });

    try {
      // 1. Global ilerlemeyi çek
      final progressData = await SaveService.loadLast();
      final List<WordCard> allLearned = progressData["learned"] ?? [];
      
      // Tekrar zamanı gelenleri bul
      final now = DateTime.now();
      final dueWords = allLearned.where((word) {
        if (word.nextReviewTimestamp == null) return false;
        try {
          final nextReview = DateTime.parse(word.nextReviewTimestamp!);
          return nextReview.isBefore(now);
        } catch (e) {
          return true;
        }
      }).toList();
      
      // Tekrar zamanı GELMEYENLER (yani öğrenilmiş sayılanlar)
      final nonDueLearned = allLearned.where((word) => !dueWords.contains(word)).toList();

      // Öğrenilecekler: main + unlearned + due (tekrar gerekenler)
      final List<WordCard> allUnlearnedOrDue = [
        ...(progressData["main"] ?? []),
        ...(progressData["unlearned"] ?? []),
        ...dueWords,
      ];

      // 2. Öğrenilmiş/Tekrar Gereken kelimeleri kategoriye göre grupla
      _learnedWordsByCategory = _groupWordsByCategory(nonDueLearned);
      _unlearnedWordsByCategory = _groupWordsByCategory(allUnlearnedOrDue);
      _learnedWordsSet = nonDueLearned.map((w) => w.englishWord).toSet(); // Set'i nonDue'ya göre kur

      // 3. İndirilen ve Önerilen desteleri çek
      final downloaded = await _deckService.getDownloadedDecks();
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
      
      // Öğrenilmiş sayılan: nextReviewTimestamp'i NULL olmayan veya tekrar tarihi gelmemiş olanlar
      int learnedCount = 0;
      final now = DateTime.now();

      for (final word in words) {
        if (word.nextReviewTimestamp != null) {
            try {
              final nextReview = DateTime.parse(word.nextReviewTimestamp!);
              if (nextReview.isAfter(now)) {
                 learnedCount++;
              }
            } catch (e) {
              // Hatalı timestamp durumunda öğrenilmemiş sayılır
            }
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
                    // İndirilenler Bölümü
                    _buildDeckSectionTitle("İndirilen Desteler"),
                    _buildDeckListView(
                      decks: _downloadedDecks,
                      isDownloadedSection: true,
                    ),
                    const SizedBox(height: 20),

                    // Önerilenler Bölümü
                    _buildDeckSectionTitle("Önerilen Desteler"),
                    _buildDeckListView(
                      decks: _recommendedDecks,
                      isDownloadedSection: false,
                    ),

                    const SizedBox(height: 30),

                    // Öğrenilen Kelimeler Bölümü (Yeni Eklendi)
                    _buildWordsSectionTitle(
                        "✅ Öğrenilen Kelimeler (${_learnedWordsByCategory.values.fold(0, (sum, list) => sum + list.length)})"),
                    _buildGroupedWordsList(_learnedWordsByCategory,
                        isLearnedSection: true),

                    const SizedBox(height: 20),

                    // Öğrenilecekler / Tekrar Gerekenler Bölümü (Yeni Eklendi)
                    _buildWordsSectionTitle(
                        "🧠 Öğrenilecek / Tekrar Gerekenler (${_unlearnedWordsByCategory.values.fold(0, (sum, list) => sum + list.length)})"),
                    _buildGroupedWordsList(_unlearnedWordsByCategory,
                        isLearnedSection: false),
                  ],
                ),
              ),
            ),
    );
  }

  // "İndirilenler" / "Önerilenler" başlığı
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

  // Yeni Başlık Stili
  Widget _buildWordsSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.indigo.shade800,
        ),
      ),
    );
  }

  // Yeni Grup Listesi Widget'ı
  Widget _buildGroupedWordsList(Map<String, List<WordCard>> groupedWords,
      {required bool isLearnedSection}) {
    if (groupedWords.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          isLearnedSection
              ? "Henüz öğrenilmiş kelime yok."
              : "Tebrikler! Öğrenilecek/Tekrar Gereken kelimeniz kalmadı.",
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedWords.keys.length,
      itemBuilder: (context, index) {
        final category = groupedWords.keys.elementAt(index);
        final words = groupedWords[category]!;
        
        final subtitleText = isLearnedSection
            ? "Tekrar Günü: ${words.first.nextReviewTimestamp != null ? words.first.nextReviewTimestamp!.substring(0, 10) : 'Yok'}"
            : "Tekrar etmek için tıkla";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            title: Text("$category (${words.length})"),
            subtitle: Text(subtitleText),
            initiallyExpanded: false,
            leading: Icon(isLearnedSection ? Icons.check_circle_outline : Icons.pending_actions,
                color: isLearnedSection ? Colors.green : Colors.deepOrange),
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.blueAccent),
                title: Text("$category grubundaki ${words.length} kelimeyi çalış"),
                onTap: () {
                  // FlashcardPage'e bu kategorideki kelimeleri gönder
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlashcardPage(words: words),
                    ),
                  ).then((_) => _loadLibraryData());
                },
              ),
              ...words.map((word) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListTile(
                      title: Text(word.englishWord),
                      subtitle: Text(word.turkishTranslation),
                      trailing: isLearnedSection ? Text(word.nextReviewTimestamp != null 
                        ? word.nextReviewTimestamp!.substring(0, 10) : 'Tekrar yok') : null,
                      dense: true,
                    ),
                  )),
            ],
          ),
        );
      },
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