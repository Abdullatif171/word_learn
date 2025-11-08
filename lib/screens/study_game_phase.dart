// lib/screens/study_game_phase.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:word_learn/models/word_card.dart';

class StudyGamePhase extends StatefulWidget {
  final List<WordCard> sessionWords;
  final Function(List<WordCard> correct, List<WordCard> incorrect, int score)
      onSessionComplete;

  const StudyGamePhase({
    Key? key,
    required this.sessionWords,
    required this.onSessionComplete,
  }) : super(key: key);

  @override
  _StudyGamePhaseState createState() => _StudyGamePhaseState();
}

class _StudyGamePhaseState extends State<StudyGamePhase> {
  int _currentIndex = 0;
  String _userInput = "";
  List<String> _shuffledLetters = [];
  WordCard? _currentWord;

  Timer? _timer;
  int _secondsElapsed = 0;
  final int _basePoints = 15;
  final int _minPoints = 5;
  int _totalScore = 0;

  final List<WordCard> _correctWords = [];
  final List<WordCard> _incorrectWords = [];

  // Steampunk teması için harf çarkı açıları
  Map<int, double> _letterAngles = {};
  final double _radius = 110.0;

  // Animasyon için
  bool _showCorrectAnimation = false;

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  void _loadWord() {
    if (_currentIndex < widget.sessionWords.length) {
      _currentWord = widget.sessionWords[_currentIndex];
      _userInput = "";
      _secondsElapsed = 0;
      _startTimer();
      // Harfleri küçük harfe çevirerek karıştır ve listele
      _shuffledLetters = _currentWord!.englishWord.toLowerCase().split('')..shuffle();
      _generateAngles(); // Her kelimede açıları yeniden hesapla
    } else {
      _timer?.cancel();
      widget.onSessionComplete(_correctWords, _incorrectWords, _totalScore);
    }
  }

  // Harfler için rastgele dönme açıları oluştur
  void _generateAngles() {
    _letterAngles.clear();
    final random = Random();
    for (int i = 0; i < _shuffledLetters.length; i++) {
      _letterAngles[i] = random.nextDouble() * 10 - 5;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  // Harf Çarkından bir harfe tıklandığında (GÜNCELLENDİ)
  void _onLetterTapped(String letter, int index) {
    // Kelimeyi zaten bildiyse yeni harf eklemeyi durdur
    if (_showCorrectAnimation) return;

    setState(() {
      _userInput += letter;
      _shuffledLetters.removeAt(index);
      _letterAngles.remove(index);

      // --- DÜZELTME: Anagram kontrolü kaldırıldı, tam eşleşme kontrolü geri geldi ---
      // Kullanıcının girdiği kelime (küçük harf) ile cevap (küçük harf) eşleşiyor mu?
      if (_userInput == _currentWord!.englishWord.toLowerCase()) {
        
        // --- KAZANMA DURUMU ---
        _timer?.cancel();
        int points = _calculatePoints();
        _totalScore += points;
        _correctWords.add(_currentWord!);

        setState(() {
          _showCorrectAnimation = true;
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          setState(() {
            _showCorrectAnimation = false;
            _currentIndex++;
            _loadWord();
          });
        });
        // --- KAZANMA DURUMU SONU ---
      }
      // --- DÜZELTME SONU ---
    });
  }


  // Harf kutusuna tıklandığında (geri silme)
  void _onInputBoxTapped(int index) {
    if (_showCorrectAnimation) return;

    setState(() {
      // _userInput'tan doğru harfi indekse göre çıkar
      String removedLetter = _userInput[index];
      _userInput = _userInput.substring(0, index) +
          _userInput.substring(index + 1);
      
      // Çıkan harfi çarka geri ekle
      _shuffledLetters.add(removedLetter);
      _generateAngles(); // Harf çarkını yeniden düzenle
    });
  }

  int _calculatePoints() {
    int points = _basePoints - (_secondsElapsed ~/ 2);
    return points.clamp(_minPoints, _basePoints);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentWord == null) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Kelime Oyunu (${_currentIndex + 1}/${widget.sessionWords.length})"),
        bottom: _buildTimer(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Soru Alanı
            Text(
              "Türkçesi:",
              style: textTheme.titleMedium
                  ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            Text(
              _currentWord!.turkishTranslation,
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              softWrap: true, // Uzun sorular için alt satıra kaydır
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Cevap Kutuları Alanı
            _buildInputBoxes(context),
            const SizedBox(height: 40),

            // Harf Çarkı Alanı
            Expanded(
              child: Center(
                child: _buildLetterWheel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Zamanlayıcı
  PreferredSizeWidget _buildTimer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double progress = 1.0 - (_secondsElapsed / (_basePoints - _minPoints) / 2);
    progress = progress.clamp(0.0, 1.0);
    
    Color progressColor =
        progress > 0.5 ? colorScheme.primary : colorScheme.error;

    return PreferredSize(
      preferredSize: const Size.fromHeight(10.0),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 10,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Kalan Puan: +${_calculatePoints()}",
                  style: TextStyle(color: progressColor, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.timer, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cevap Kutuları (Kelime Gruplamalı)
  Widget _buildInputBoxes(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Animasyon için dinamik değerler
    final Color shadowColor = _showCorrectAnimation
        ? Colors.green.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.3);

    final Color borderColor = _showCorrectAnimation
        ? Colors.green
        : colorScheme.primary.withValues(alpha: 0.5);

    final double blurRadius = _showCorrectAnimation ? 10 : 4;
    final double spreadRadius = _showCorrectAnimation ? 2 : 0;

    // Kelimeyi boşluklara göre böl
    final List<String> words = _currentWord!.englishWord.toLowerCase().split(' ');
    int globalCharIndex = 0; // _userInput string'i içindeki genel indeksi takip eder

    List<Widget> wordRows = [];

    for (String word in words) {
      List<Widget> letterBoxes = [];
      
      // Kelimenin harfleri için kutuları oluştur
      for (int i = 0; i < word.length; i++) {
        final int currentIndex = globalCharIndex; // Tıklama için mevcut global indeksi yakala

        letterBoxes.add(
          GestureDetector(
            onTap: () {
              if (currentIndex < _userInput.length) {
                _onInputBoxTapped(currentIndex); // Tıklamada global indeksi kullan
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 40,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: borderColor, width: 1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: blurRadius,
                    spreadRadius: spreadRadius,
                    offset: const Offset(2, 2),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  // _userInput'tan doğru harfi global indekse göre al
                  currentIndex < _userInput.length ? _userInput[currentIndex].toUpperCase() : "",
                  style: textTheme.headlineSmall?.copyWith(
                    color: _showCorrectAnimation
                        ? Colors.green
                        : colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
        globalCharIndex++; // Her harften sonra global indeksi artır
      }
      
      // Harf kutularını bir Row içine al (bu bir kelimeyi temsil eder)
      wordRows.add(
        Row(
          mainAxisSize: MainAxisSize.min, // Row'un küçülmesini sağla
          mainAxisAlignment: MainAxisAlignment.center,
          children: letterBoxes,
        )
      );

      // Kelimeler arasındaki boşluğu da global indekse ekle
      // (Eğer son kelime değilse)
      if (word != words.last) {
        globalCharIndex++; // Boşluk karakteri için indeksi artır
      }
    }
    
    // Tüm kelime Row'larını bir Wrap içine yerleştir
    return Wrap(
      alignment: WrapAlignment.center, // Tüm kelimeleri ortala
      runSpacing: 8.0, // Alt satıra kayan kelimeler için dikey boşluk
      spacing: 12.0, // Aynı satırdaki kelimeler arası yatay boşluk
      children: wordRows,
    );
  }

  // Harf Çarkı
  Widget _buildLetterWheel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final List<Widget> letters = [];
    double angleIncrement = (2 * pi) / _shuffledLetters.length;

    for (int i = 0; i < _shuffledLetters.length; i++) {
      double angle = angleIncrement * i;
      double x = _radius * cos(angle);
      double y = _radius * sin(angle);
      
      double rotationAngle = _letterAngles[i] ?? 0.0;

      letters.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: y + _radius,
          left: x + _radius,
          child: Transform.rotate(
            angle: rotationAngle * (pi / 180),
            child: GestureDetector(
              onTap: () => _onLetterTapped(_shuffledLetters[i], i),
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.8),
                      colorScheme.primary,
                      colorScheme.secondary.withValues(alpha: 0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.secondary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 5,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _shuffledLetters[i].toUpperCase(),
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Çarkın merkezi
    return SizedBox(
      width: _radius * 2 + 60,
      height: _radius * 2 + 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan dişlisi (dekoratif)
          Container(
            width: _radius * 1.5,
            height: _radius * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surface.withValues(alpha: 0.5),
              border: Border.all(color: colorScheme.secondary, width: 4, style: BorderStyle.solid),
            ),
            child: Icon(Icons.settings, color: colorScheme.surface, size: 50),
          ),
          ...letters,
        ],
      ),
    );
  }
}