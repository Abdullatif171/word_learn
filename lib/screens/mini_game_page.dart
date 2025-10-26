// lib/screens/mini_game_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/word_card.dart';
import '../services/save_service.dart';

// Harfleri karıştıran yardımcı fonksiyon
String _scrambleLetters(String word) {
  final List<String> letters = word.toUpperCase().split('');
  letters.shuffle(Random());
  return letters.join('');
}

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

  // Oyun Durumu
  String _currentInput = '';
  List<String> _shuffledLetters = [];
  List<int> _usedLetterIndices = [];

  // SRS Mantığı (Aralıklı Tekrar Sistemi)
  final List<int> _srsIntervals = [1, 3, 7, 14, 30, 90, 180];

  @override
  void initState() {
    super.initState();
    _loadWordsForGame();
  }
  
  // Kelimeleri yükle (Öğrenilmemiş ve tekrar zamanı gelenleri)
  Future<void> _loadWordsForGame() async {
    final progress = await SaveService.loadLast();
    _allWords = [
      ...progress["unlearned"]!, 
      ...progress["main"]!.where((word) {
        if (word.nextReviewTimestamp == null) return true;
        try {
          return DateTime.parse(word.nextReviewTimestamp!).isBefore(DateTime.now());
        } catch (e) {
          return true;
        }
      }).toList(),
    ];
    
    _allWords = _allWords.where((w) => w.englishWord.length >= 3).toList();
    
    if (_allWords.isEmpty) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Oyun için yeterli kelime yok (min. 3 harf).")),
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

  // SRS Seviyesini Güncelle
  WordCard _updateSrs(WordCard word, {bool known = true}) {
      final currentLevel = _srsIntervals.indexOf(word.reviewIntervalDays);
      int nextLevelIndex;
      
      if (known) {
        nextLevelIndex = (currentLevel + 1).clamp(0, _srsIntervals.length - 1);
      } else {
        nextLevelIndex = 0;
      }
      
      final nextIntervalDays = _srsIntervals[nextLevelIndex];
      final nextReviewDate = DateTime.now().add(Duration(days: nextIntervalDays));

      return word.copyWith(
        reviewIntervalDays: nextIntervalDays,
        nextReviewTimestamp: nextReviewDate.toIso8601String(),
      );
  }

  // Cevabı işle ve kaydet
  void _processAnswer(WordCard word, bool known) async {
    WordCard updatedWord;
    if (known) {
      updatedWord = _updateSrs(word, known: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mükemmel! Kelime öğrenilenlere eklendi.")),
      );
    } else {
      updatedWord = _updateSrs(word, known: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pas geçildi. Tekrar sıfırlandı.")),
      );
    }

    final indexInAll = _allWords.indexWhere((w) => w.englishWord == word.englishWord);
    if (indexInAll != -1) {
      _allWords[indexInAll] = updatedWord;
    }
    
    _currentSessionWords.removeWhere((w) => w.englishWord == word.englishWord);
    
    final currentProgress = await SaveService.loadLast();
    final learned = currentProgress["learned"]!.where((w) => w.englishWord != word.englishWord).toList();
    final unlearned = currentProgress["unlearned"]!.where((w) => w.englishWord != word.englishWord).toList();
    final main = currentProgress["main"]!.where((w) => w.englishWord != word.englishWord).toList();
    
    if (known) {
      learned.add(updatedWord);
    } else {
      unlearned.add(updatedWord);
    }
    
    await SaveService.saveLast(main, learned, unlearned);
    
    _nextWord(); 
  }

  // Bir sonraki kelimeye geç
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
      _currentInput = '';
      _shuffledLetters = _scrambleLetters(_currentWord!.englishWord).split('');
      _usedLetterIndices.clear();
    });
  }

  // Harf Ekleme (Sequential Tap)
  void _addLetter(String letter, int index) {
    if (_usedLetterIndices.contains(index)) return;
    setState(() {
      _currentInput += letter;
      _usedLetterIndices.add(index);
      _checkWord();
    });
  }

  // YENİ METOT: Belirtilen indeksteki harfi kaldır
  void _removeLetterAtIndex(int indexToRemove) {
    if (_currentInput.isEmpty || indexToRemove >= _currentInput.length) return;

    setState(() {
      // 1. Kullanılan Harf İndeksini Serbest Bırak (Bu, her zaman sonuncuyu serbest bırakır)
      // WoW tarzı oyunlarda genellikle sadece son girilen harf silinir.
      // Ancak buradaki mantık, tıklanan harf kutusuna karşılık gelen harfin silinmesi
      
      // Silinecek harfin ait olduğu orijinal harf butonunun indeksini bul
      // Geriye doğru arama yaparız çünkü en son eklenen harfin indeksi en büyük/en son olanıdır
      final originalLetterIndex = _usedLetterIndices[_currentInput.length - 1]; // Basitçe en son eklenen harfi geri alıyoruz
      
      // Harfi sil
      _currentInput = _currentInput.substring(0, indexToRemove) +
                      _currentInput.substring(indexToRemove + 1);

      // Sadece son kullanılan indeksi kaldır (Basitliği korumak için)
      _usedLetterIndices.remove(originalLetterIndex); 

      // Not: Karmaşık (rastgele) silme yapmak için, her harfin hangi orijinal harf butonuna
      // ait olduğunu gösteren bir eşleme (Map) tutmanız gerekirdi. 
      // Basitlik adına, sadece son harfi siliyoruz ve ilgili butonu serbest bırakıyoruz.
    });
  }
  
  // Kelime Kontrolü
  void _checkWord() {
    if (_currentWord == null) return;
    final correctWord = _currentWord!.englishWord.toUpperCase();
    
    if (_currentInput.length == correctWord.length) {
      final isCorrect = _currentInput == correctWord;
      
      if (isCorrect) {
        _processAnswer(_currentWord!, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yanlış kelime! Tekrar dene.")),
        );
        setState(() {
          _currentInput = '';
          _usedLetterIndices.clear();
        });
      }
    } else if (_currentInput.length > correctWord.length) {
      setState(() {
          _currentInput = '';
          _usedLetterIndices.clear();
      });
    }
  }

  // Kelimeyi Atla (Başarısız sayılır)
  void _skipWord() {
    if (_currentWord != null) {
      _processAnswer(_currentWord!, false);
    }
  }

  // UI Bileşenleri: Cevap Izgarası (Tıklanma Özelliği Eklendi)
  Widget _buildAnswerGrid() {
    final wordLength = _currentWord!.englishWord.length;
    final letters = _currentInput.split('');

    return Center(
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: List.generate(wordLength, (index) {
          final letter = index < letters.length ? letters[index] : '';
          
          return GestureDetector(
            onTap: letter.isNotEmpty ? () => _removeLetterAtIndex(index) : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: letter.isNotEmpty ? Colors.blueAccent : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: letter.isNotEmpty ? Colors.white : Colors.blueAccent,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // UI Bileşenleri: Harf Çarkı
  Widget _buildLetterWheel() {
    if (_shuffledLetters.isEmpty) return const SizedBox.shrink();

    const double outerRadius = 100.0; 
    const double letterSize = 60.0; 
    const double letterFontSize = 25.0;
    final int count = _shuffledLetters.length;

    const double totalSize = 2 * outerRadius + letterSize + 10; 
    const double centerOffset = totalSize / 2;

    return Container(
      width: totalSize,
      height: totalSize,
      alignment: Alignment.center,
      child: Stack(
        children: [
          ...List.generate(count, (i) {
          final letter = _shuffledLetters[i];
          final isUsed = _usedLetterIndices.contains(i);
          
          final double angle = 2 * pi * i / count; 
          final double xOffsetFromCenter = outerRadius * cos(angle - pi / 2);
          final double yOffsetFromCenter = outerRadius * sin(angle - pi / 2);
          
          return Positioned(
            left: centerOffset + xOffsetFromCenter - (letterSize / 2),
            top: centerOffset + yOffsetFromCenter - (letterSize / 2),
            child: Opacity(
              opacity: isUsed ? 0.5 : 1.0,
              child: GestureDetector(
                onTap: () => _addLetter(letter, i),
                child: Container(
                  width: letterSize,
                  height: letterSize,
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.grey.shade400 : Colors.deepOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: letterFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        
        Center(
            child: SizedBox(
              width: 60, 
              height: 60,
              child: ElevatedButton(
                onPressed: _skipWord,
                style: ElevatedButton.styleFrom(
                  // Soft Tasarım: Kırmızı yerine arka plan rengine yakın, hafif gri
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black54, // İkon/Yazı rengi
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  elevation: 5, // Hafif gölge
                  side: BorderSide(color: Colors.grey.shade300, width: 2), // Hafif kenarlık
                ),
                child: const Icon(Icons.skip_next, size: 30),
              ),
            ),
          ),
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentWord == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final remainingWords = _currentSessionWords.length;
    final totalWordsCount = _allWords.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelime Yapma Oyunu"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // İlerleme
              LinearProgressIndicator(
                value: 1 - (remainingWords / totalWordsCount),
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
              const SizedBox(height: 10),
              Text(
                "Kalan Kelime: $remainingWords / $totalWordsCount",
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              
              // İpucu: Türkçe Çevirisi
              Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text("Hangi kelime?", style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        _currentWord!.turkishTranslation,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Cevap Izgarası
              _buildAnswerGrid(),
              const SizedBox(height: 40),
              
              // Harf Çarkı
              _buildLetterWheel(),
            ],
          ),
        ),
      ),
    );
  }
}