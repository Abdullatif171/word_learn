import 'dart:math';
import 'package:flutter/material.dart';
import 'package:word_learn/models/word_card.dart';

// Harfleri karıştıran yardımcı fonksiyon
String _scrambleLetters(String word) {
  final List<String> letters = word.toUpperCase().split('');
  letters.shuffle(Random());
  return letters.join('');
}

class StudyGamePhase extends StatefulWidget {
  final List<WordCard> wordsToTest;
  final Function(int score, List<WordCard> correct, List<WordCard> incorrect)
      onFinished;

  const StudyGamePhase({
    super.key,
    required this.wordsToTest,
    required this.onFinished,
  });

  @override
  State<StudyGamePhase> createState() => _StudyGamePhaseState();
}

class _StudyGamePhaseState extends State<StudyGamePhase> {
  // Bu oturum için gelen kelimeler
  List<WordCard> _currentSessionWords = [];
  WordCard? _currentWord;
  bool _isLoading = true;

  // Oturum puanı ve sonuç listeleri
  int _score = 0;
  final List<WordCard> _correct = [];
  final List<WordCard> _incorrect = [];

  // Oyun Durumu
  String _currentInput = '';
  List<String> _shuffledLetters = [];
  List<int> _usedLetterIndices = [];

  @override
  void initState() {
    super.initState();
    _loadWordsForGame();
  }

  // Kelimeleri SaveService'ten yüklemek yerine widget'tan al
  void _loadWordsForGame() {
    _currentSessionWords = List.from(widget.wordsToTest);
    
    // Kelime yapma oyunu 3 harften kısa kelimelerde iyi çalışmaz
    _currentSessionWords.removeWhere((w) => w.englishWord.length < 3);
    
    _currentSessionWords.shuffle();
    
    if (_currentSessionWords.isEmpty) {
       // Oynanacak uygun kelime yoksa
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Oyun için yeterli kelime yok (min. 3 harf).")),
         );
         // Oyunu atla (0 puanla bitir)
         widget.onFinished(0, [], []);
       }
       return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _nextWord();
      });
    }
  }

  // SRS mantığı ve kaydetme (processAnswer) buradan kaldırıldı.
  // Sonuçları artık ana yönetici (StudySessionPage) kaydedecek.

  // Bir sonraki kelimeye geç
  void _nextWord() {
    if (_currentSessionWords.isEmpty) {
      if (mounted) {
        // Oturum bitti! Sonuçları ana yöneticiye gönder.
        widget.onFinished(_score, _correct, _incorrect);
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

  void _addLetter(String letter, int index) {
    if (_usedLetterIndices.contains(index)) return;
    setState(() {
      _currentInput += letter;
      _usedLetterIndices.add(index);
      _checkWord();
    });
  }

  void _removeLetterAtIndex(int indexToRemove) {
     if (_currentInput.isEmpty) return;
     
     // Sadece son harfi sil (basitlik için)
     setState(() {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        _usedLetterIndices.removeLast();
     });
  }
  
  // Kelime Kontrolü
  void _checkWord() {
    if (_currentWord == null) return;
    final correctWord = _currentWord!.englishWord.toUpperCase();
    
    if (_currentInput.length == correctWord.length) {
      final isCorrect = _currentInput == correctWord;
      
      if (isCorrect) {
        // Doğruysa: Puan ve listeye ekle
        _score += 10; 
        _correct.add(_currentWord!);
        _currentSessionWords.removeWhere((w) => w.englishWord == _currentWord!.englishWord);
        
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Mükemmel! 🔥 +10 Puan"), duration: Duration(milliseconds: 1000)),
        );
        
        // Sonraki kelimeye geç
        Future.delayed(const Duration(milliseconds: 1000), _nextWord);

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
      // Yanlış listesine ekle
      _incorrect.add(_currentWord!);
      _currentSessionWords.removeWhere((w) => w.englishWord == _currentWord!.englishWord);
      
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Pas geçildi: ${_currentWord!.englishWord}"), duration: Duration(milliseconds: 1000)),
      );

      // Sonraki kelimeye geç
      Future.delayed(const Duration(milliseconds: 1000), _nextWord);
    }
  }

  // UI Bileşenleri: Cevap Izgarası
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
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black54, 
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  elevation: 5, 
                  side: BorderSide(color: Colors.grey.shade300, width: 2), 
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
    
    // Kalan kelime sayısını _currentSessionWords'ten değil, widget'tan alarak hesaplayalım
    final int totalInSession = widget.wordsToTest.length;
    final int completedCount = _correct.length + _incorrect.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aşama 2: Kelime Yapma Oyunu"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Geri gitmeyi engelle
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // İlerleme
              LinearProgressIndicator(
                value: (completedCount) / totalInSession,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
              const SizedBox(height: 10),
              Text(
                "Kelime: ${completedCount + 1} / $totalInSession",
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