import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/word_card.dart';
import '../widgets/flashcard.dart';
import '../widgets/mini_flashcard_stack.dart';
import '../services/save_service.dart';

class FlashcardPage extends StatefulWidget {
  final List<WordCard>? words;
  final bool continueFromLast;
  final String? loadSlot;
  final bool loadUnlearnedOnly; // Yeni eklendi (Rastgele Öğren için)

  const FlashcardPage({
    super.key,
    this.words,
    this.continueFromLast = false,
    this.loadSlot,
    this.loadUnlearnedOnly = false, // Varsayılan değer
  });

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  List<WordCard> mainWords = [];
  List<WordCard> learnedWords = [];
  List<WordCard> unLearnedWords = [];
  int totalWords = 0;

  // Basitleştirilmiş SRS aralıkları (gün cinsinden)
  final List<int> _srsIntervals = [1, 3, 7, 14, 30, 90, 180];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void didUpdateWidget(FlashcardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.words != oldWidget.words) {
      _loadWords();
    }
  }

  // Öğrenilmiş bir kelime için bir sonraki tekrar zamanını ve seviyesini hesaplar
  WordCard _updateSrs(WordCard word) {
    // Mevcut aralığı bul
    final currentLevel = _srsIntervals.indexOf(word.reviewIntervalDays);
    // Bir sonraki seviyeye geç (maksimum aralığı geçmesin)
    final nextLevelIndex = (currentLevel + 1).clamp(0, _srsIntervals.length - 1);
    final nextIntervalDays = _srsIntervals[nextLevelIndex];

    final nextReviewDate = DateTime.now().add(Duration(days: nextIntervalDays));

    return word.copyWith(
      reviewIntervalDays: nextIntervalDays,
      nextReviewTimestamp: nextReviewDate.toIso8601String(),
    );
  }
  
  // Bilinmeyen bir kelime için SRS'yi sıfırlar
  WordCard _resetSrs(WordCard word) {
    return word.copyWith(
      reviewIntervalDays: 0, // 0: Yeni kelime olarak başla
      nextReviewTimestamp: null,
    );
  }

  // Tekrar zamanı gelen kelimeleri ana desteye taşır
  void _moveDueWordsToMain() {
    final now = DateTime.now();
    final dueWords = learnedWords.where((word) {
      if (word.nextReviewTimestamp == null) return false;
      try {
        final nextReview = DateTime.parse(word.nextReviewTimestamp!);
        return nextReview.isBefore(now);
      } catch (e) {
        // Hatalı timestamp varsa tekrar edilmesi için sayılır
        return true;
      }
    }).toList();

    if (dueWords.isNotEmpty) {
      // Due olanları öğrendiklerinden çıkar ve ana desteye (resetlenmiş olarak) ekle
      learnedWords.removeWhere((word) => dueWords.contains(word));
      mainWords.addAll(dueWords.map((word) => _resetSrs(word)));
      mainWords.shuffle();
    }
  }

  Future<void> _loadWords() async {
    List<WordCard> wordsToLoad;
    if (widget.words != null) {
      wordsToLoad = widget.words!;
      setState(() {
        mainWords = wordsToLoad;
        learnedWords = [];
        unLearnedWords = [];
        totalWords = wordsToLoad.length;
      });
      return;
    }

    final Map<String, List<WordCard>> progress;

    if (widget.loadSlot != null) {
      progress = await SaveService.loadSlot(widget.loadSlot!);
    } else if (widget.continueFromLast || widget.loadUnlearnedOnly) {
      progress = await SaveService.loadLast();
    } else {
      // Eğer ne bir slot ne de son kayıt varsa, tüm kelimeleri yükle
      final String jsonString = await rootBundle.loadString('assets/words.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      wordsToLoad = jsonList.map((e) => WordCard.fromJson(e)).toList();
      progress = {"main": wordsToLoad, "learned": [], "unlearned": []};
    }
    
    // Kelimeleri yükle
    mainWords = progress["main"]!;
    learnedWords = progress["learned"]!;
    unLearnedWords = progress["unlearned"]!;
    
    // Eğer 'Rastgele Öğren' modu aktifse, sadece öğrenilmemiş/tekrar gereken kelimelerle başla
    if (widget.loadUnlearnedOnly) {
      // Ana desteye öğrenilmemişleri ekle
      mainWords.addAll(unLearnedWords);
      unLearnedWords.clear();
      
      // Tüm öğrenilmiş kelimelerden, tekrar zamanı gelmiş olanları ana desteye taşı
      _moveDueWordsToMain();
      
      // totalWords hala tüm kelime sayısını temsil etmeli.
      totalWords = mainWords.length + learnedWords.length + unLearnedWords.length;
      
    } else {
      // Normal yükleme: Tekrar zamanı gelenleri ana desteye taşı
      _moveDueWordsToMain();
      totalWords = mainWords.length + learnedWords.length + unLearnedWords.length;
    }

    // Öğrenilmiş kelimeleri bir sonraki tekrar zamanına göre sırala (sadece görünüm için)
    learnedWords.sort((a, b) => 
        (a.nextReviewTimestamp ?? DateTime.now().toIso8601String())
        .compareTo(b.nextReviewTimestamp ?? DateTime.now().toIso8601String()));


    if (!mounted) return;
    setState(() {
      mainWords.shuffle(); // Ana desteyi karıştır
    });
  }

  void _moveToLearned(WordCard word) {
    setState(() {
      mainWords.remove(word);
      unLearnedWords.remove(word); // Unlearned'da da olabilir
      learnedWords.add(_updateSrs(word)); // SRS güncellemesi
      learnedWords.sort((a, b) => 
            (a.nextReviewTimestamp ?? DateTime.now().toIso8601String())
            .compareTo(b.nextReviewTimestamp ?? DateTime.now().toIso8601String()));
      _saveLast();
    });
  }

  void _moveToUnLearned(WordCard word) {
    setState(() {
      mainWords.remove(word);
      learnedWords.remove(word); // Learned'da da olabilir
      unLearnedWords.add(_resetSrs(word)); // SRS sıfırlaması
      _saveLast();
    });
  }

  void _learnedWordsMoveToMain(WordCard word) {
    setState(() {
      learnedWords.remove(word);
      mainWords.add(_resetSrs(word)); // SRS sıfırlaması
      mainWords.shuffle();
      _saveLast();
    });
  }

  void _unLearnedWordsMoveToMain(WordCard word) {
    setState(() {
      unLearnedWords.remove(word);
      mainWords.add(_resetSrs(word)); // SRS sıfırlaması
      mainWords.shuffle();
      _saveLast();
    });
  }

  Future<void> _saveLast() async {
    await SaveService.saveLast(mainWords, learnedWords, unLearnedWords);
  }

  Future<void> _saveSlot() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kayıt Oluştur'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Kayıt Adı'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await SaveService.saveSlot(
                  nameController.text,
                  mainWords,
                  learnedWords,
                  unLearnedWords,
                );
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  double get _progress {
    if (totalWords == 0) return 0.0;
    // Toplam öğrenilen kelime: learnedWords.length
    return learnedWords.length / totalWords;
  }

  String get _progressText {
    return 'İlerleme: ${learnedWords.length}/$totalWords';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => _saveLast(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Kelime Kartları"),
          centerTitle: true,
          elevation: 4,
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.bookmark),
                onPressed: _saveSlot,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: mainWords.isEmpty && learnedWords.isEmpty && unLearnedWords.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    if (mainWords.isNotEmpty)
                      Center(
                        child: Flashcard(
                          key: ValueKey(mainWords[0].englishWord),
                          word: mainWords[0],
                          known: _moveToLearned,
                          unknown: _moveToUnLearned,
                          isLearned: false,
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          // build tamamlanınca anasayfaya dön
                          Future.microtask(() {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Tüm kelimeleri öğrendiniz! Ana sayfaya dönüldü.",
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          });

                          return const Center(
                            child:
                                CircularProgressIndicator(), // küçük bekleme animasyonu
                          );
                        },
                      ),
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _progressText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 20,
                      child: Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           MiniFlashcardStack(
                            learnedWords: learnedWords.take(5).toList(),
                            onTap: _learnedWordsMoveToMain,
                          ),
                          Text(
                            "Öğrenilen: ${learnedWords.length}",
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                          ),
                         ],
                      ),
                    ),
                    Positioned(
                      bottom: 5,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MiniFlashcardStack(
                            learnedWords: unLearnedWords.take(5).toList(),
                            onTap: _unLearnedWordsMoveToMain,
                          ),
                          Text(
                            "Bilinmeyen: ${unLearnedWords.length}",
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}