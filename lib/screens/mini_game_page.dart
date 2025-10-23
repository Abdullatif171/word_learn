// lib/screens/mini_game_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/word_card.dart';
import '../services/save_service.dart';

class MiniGamePage extends StatefulWidget {
  const MiniGamePage({super.key});

  @override
  State<MiniGamePage> createState() => _MiniGamePageState();
}

class _MiniGamePageState extends State<MiniGamePage> {
  List<WordCard> _allWords = [];
  List<WordCard> _currentSessionWords = [];
  WordCard? _currentWord;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWordsForGame();
  }
  
  // FlashcardPage'deki load mantığının basitleştirilmiş hali
  Future<void> _loadWordsForGame() async {
    final progress = await SaveService.loadLast();
    // Oyun için sadece öğrenilmemişler (unlearned) ve tekrar zamanı gelenler (mainWords)
    // Tekrar zamanı gelenler, main listesinden filtrelenir.
    _allWords = [
      ...progress["unlearned"]!, 
      ...progress["main"]!.where((word) {
        if (word.nextReviewTimestamp == null) return true;
        try {
          return DateTime.parse(word.nextReviewTimestamp!).isBefore(DateTime.now());
        } catch (e) {
          return true; // Hatalı zaman damgası varsa tekrar edilmesi gerekir
        }
      }).toList(),
    ];
    
    if (_allWords.isEmpty) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Oyun için yeterli kelime yok. Tüm kelimeler öğrenilmiş veya tekrar zamanı gelmemiş!")),
         );
         Navigator.of(context).pop();
       }
       return;
    }

    _allWords.shuffle();
    _currentSessionWords = List.from(_allWords);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _nextWord();
      });
    }
  }

  // SRS Mantığı (FlashcardPage'den kopyalanmıştır)
  final List<int> _srsIntervals = [1, 3, 7, 14, 30, 90, 180];
  WordCard _updateSrs(WordCard word, {bool known = true}) {
      final currentLevel = _srsIntervals.indexOf(word.reviewIntervalDays);
      int nextLevelIndex;
      
      if (known) {
        nextLevelIndex = (currentLevel + 1).clamp(0, _srsIntervals.length - 1);
      } else {
        // Bilinmezse en küçük aralığa getir
        nextLevelIndex = 0;
      }
      
      final nextIntervalDays = _srsIntervals[nextLevelIndex];
      final nextReviewDate = DateTime.now().add(Duration(days: nextIntervalDays));

      return word.copyWith(
        reviewIntervalDays: nextIntervalDays,
        nextReviewTimestamp: nextReviewDate.toIso8601String(),
      );
  }
  
  // Kelimeyi bildi veya bilemedi olarak işaretle ve kaydet
  void _processAnswer(WordCard word, bool known) async {
    WordCard updatedWord;
    if (known) {
      updatedWord = _updateSrs(word, known: true);
    } else {
      updatedWord = _updateSrs(word, known: false);
    }

    // Kelimeyi ana listede bul ve SRS seviyesini güncelle
    final indexInAll = _allWords.indexWhere((w) => w.englishWord == word.englishWord);
    if (indexInAll != -1) {
      _allWords[indexInAll] = updatedWord;
    }
    
    // Anlık session'dan kaldır
    _currentSessionWords.removeWhere((w) => w.englishWord == word.englishWord);
    
    // SaveService'ı güncelle
    final currentProgress = await SaveService.loadLast();
    
    // Kelimenin tüm listelerdeki eski kaydını sil
    final learned = currentProgress["learned"]!.where((w) => w.englishWord != word.englishWord).toList();
    final unlearned = currentProgress["unlearned"]!.where((w) => w.englishWord != word.englishWord).toList();
    final main = currentProgress["main"]!.where((w) => w.englishWord != word.englishWord).toList();
    
    // Kelimeyi yeni durumuna göre doğru listeye ekle
    if (known) {
      learned.add(updatedWord);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doğru! Tekrar aralığı arttırıldı.")),
      );
    } else {
      unlearned.add(updatedWord);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yanlış. Tekrar sıfırlandı.")),
      );
    }
    
    // Tüm güncel listelerle kaydet
    await SaveService.saveLast(main, learned, unlearned);

    _nextWord(); 
  }
  
  void _nextWord() {
    if (_currentSessionWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tebrikler! Tüm kelimeleri tamamladınız.")),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    setState(() {
      _currentWord = _currentSessionWords.first;
    });
  }

  // Yanıltıcı cevaplar için diğer kelimelerin çevirilerini al
  List<String> _getDistractors(String correctAnswer) {
    // Tüm kelimeler havuzundan 3 farklı yanlış çeviri seç
    final List<String> allTranslations = _allWords
        .where((w) => w.turkishTranslation != correctAnswer)
        .map((w) => w.turkishTranslation)
        .toList();
    
    allTranslations.shuffle();
    return allTranslations.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentWord == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final correctAnswer = _currentWord!.turkishTranslation;
    final List<String> wrongAnswers = _getDistractors(correctAnswer);
        
    // Yanıtları birleştir ve karıştır
    final List<String> allAnswers = [correctAnswer, ...wrongAnswers];
    allAnswers.shuffle();
    
    // Soru: İngilizce kelime
    final question = _currentWord!.englishWord;
    final remainingWords = _currentSessionWords.length;
    final totalWordsCount = _allWords.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelime Bombası"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // İlerleme Çubuğu/Sayaç
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: LinearProgressIndicator(
                value: 1 - (remainingWords / totalWordsCount),
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
            ),
            Text(
              "Kalan Kelime: $remainingWords / $totalWordsCount",
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            
            // Soru Kartı
            Card(
              elevation: 4,
              child: Container(
                alignment: Alignment.center,
                height: 150,
                child: Text(
                  question,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // Cevap Butonları
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: allAnswers.length.clamp(0, 4),
                itemBuilder: (context, index) {
                  final answer = allAnswers[index];
                  final isCorrect = answer == correctAnswer;
                  
                  return ElevatedButton(
                    onPressed: () => _processAnswer(_currentWord!, isCorrect),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.deepOrange, width: 2),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: Text(answer, textAlign: TextAlign.center),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}