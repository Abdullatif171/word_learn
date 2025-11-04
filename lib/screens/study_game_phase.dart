import 'dart:async'; 
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:word_learn/models/word_card.dart';

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
  List<WordCard> _currentSessionWords = [];
  WordCard? _currentWord;
  bool _isLoading = true;

  int _score = 0;
  final List<WordCard> _correct = [];
  final List<WordCard> _incorrect = [];

  String _currentInput = '';
  List<String> _shuffledLetters = [];
  List<int> _usedLetterIndices = [];

  // --- YENİ EKLENENLER (Süre için) ---
  Timer? _wordTimer;
  int _secondsElapsed = 0;
  static const int _basePoints = 15; // Maksimum puan
  static const int _minPoints = 5;  // Minimum puan
  // ---------------------------------

  @override
  void initState() {
    super.initState();
    _loadWordsForGame();
  }

  @override
  void dispose() {
    _wordTimer?.cancel(); // Sayfa kapanırsa zamanlayıcıyı durdur
    super.dispose();
  }

  void _loadWordsForGame() {
    _currentSessionWords = List.from(widget.wordsToTest);
    _currentSessionWords.removeWhere((w) => w.englishWord.length < 3);
    _currentSessionWords.shuffle();
    
    if (_currentSessionWords.isEmpty) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Oyun için yeterli kelime yok (min. 3 harf).")),
         );
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

  // Bir sonraki kelimeye geç
  void _nextWord() {
    // Önceki zamanlayıcıyı durdur
    _wordTimer?.cancel();

    if (_currentSessionWords.isEmpty) {
      if (mounted) {
        widget.onFinished(_score, _correct, _incorrect);
      }
      return;
    }
    
    setState(() {
      _currentWord = _currentSessionWords.first;
      _currentInput = '';
      _shuffledLetters = _scrambleLetters(_currentWord!.englishWord).split('');
      _usedLetterIndices.clear();
      
      // YENİ: Zamanlayıcıyı başlat
      _secondsElapsed = 0;
      _wordTimer = Timer.periodic(const Duration(seconds: 1), (timer) { 
        setState(() {
          _secondsElapsed++; 
        });
      });
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
     setState(() {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        _usedLetterIndices.removeLast();
     });
  }
  
  // Kelime Kontrolü (GÜNCELLENDİ)
  void _checkWord() {
    if (_currentWord == null) return;
    final correctWord = _currentWord!.englishWord.toUpperCase();
    
    if (_currentInput.length == correctWord.length) {
      final isCorrect = _currentInput == correctWord;
      
      if (isCorrect) {
        // YENİ: Puanı süreye göre hesapla
        _wordTimer?.cancel();
        // Hızlı cevap = 15 puan. Her 2 saniyede 1 puan düşer, min 5 puan.
        int points = _basePoints - (_secondsElapsed ~/ 2);
        points = points.clamp(_minPoints, _basePoints); // Puanı min/max aralığında tut
        
        _score += points; 
        _correct.add(_currentWord!);
        _currentSessionWords.removeWhere((w) => w.englishWord == _currentWord!.englishWord);
        
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Mükemmel! 🔥 +$points Puan"), duration: const Duration(milliseconds: 1000)),
        );
        
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

  // Kelimeyi Atla (GÜNCELLENDİ)
  void _skipWord() {
    if (_currentWord != null) {
      _wordTimer?.cancel(); // Zamanlayıcıyı durdur
      
      _incorrect.add(_currentWord!);
      _currentSessionWords.removeWhere((w) => w.englishWord == _currentWord!.englishWord);
      
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Pas geçildi: ${_currentWord!.englishWord}"), duration: const Duration(milliseconds: 1000)),
      );

      Future.delayed(const Duration(milliseconds: 1000), _nextWord);
    }
  }
  
  // YENİ METOT: Erken çıkış onayı
  Future<bool> _onWillPop() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oyundan Çık'),
        content: const Text('Şu anki ilerlemeniz (bu oturum için) kaydedilmeyecek. Çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Çık', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  // --- UI METOTLARI (değişmedi) ---
  Widget _buildAnswerGrid() {
    // ... (Bu metot değişmedi) ...
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

  Widget _buildLetterWheel() {
    // ... (Bu metot değişmedi) ...
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
  // --- UI Metotları Sonu ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentWord == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final int totalInSession = widget.wordsToTest.length;
    final int completedCount = _correct.length + _incorrect.length;

    // YENİ WIDGET: PopScope
    return PopScope(
      canPop: false, // Otomatik çıkışı engelle
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          _wordTimer?.cancel(); // Çıkarken zamanlayıcıyı durdur
          Navigator.pop(context); // Onaylanırsa manuel çık
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Aşama 2: Kelime Yapma Oyunu"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          // automaticallyImplyLeading: false, // Geri tuşunu göstermek için bu satırı SİLİN
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Kelime: ${completedCount + 1} / $totalInSession",
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    // YENİ: Süre Göstergesi
                    Text(
                      "Süre: $_secondsElapsed sn",
                      style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
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
      ),
    );
  }
}