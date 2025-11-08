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
      _shuffledLetters = _currentWord!.englishWord.split('')..shuffle();
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
      // Harflerin üst üste binmesini önlemek için küçük rastgelelik
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

  // Harf Çarkından bir harfe tıklandığında
  void _onLetterTapped(String letter, int index) {
    setState(() {
      _userInput += letter;
      _shuffledLetters.removeAt(index); // Kullanılan harfi çarktan kaldır
      _letterAngles.remove(index); // Açısını da kaldır

      // Cevap doğru mu kontrol et
      if (_userInput == _currentWord!.englishWord) {
        _timer?.cancel();
        int points = _calculatePoints();
        _totalScore += points;
        _correctWords.add(_currentWord!);
        
        // TODO: Doğru cevap animasyonu (örn. yeşil parlama)
        
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _currentIndex++;
            _loadWord();
          });
        });
      }
    });
  }

  // Harf kutusuna tıklandığında (geri silme)
  void _onInputBoxTapped(int index) {
    setState(() {
      String removedLetter = _userInput[index];
      _userInput = _userInput.substring(0, index) +
          _userInput.substring(index + 1);
      _shuffledLetters.add(removedLetter); // Harfi çarka geri ekle
      _generateAngles(); // Geri eklenen harf için yeni açı
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
        bottom: _buildTimer(context), // Zamanlayıcıyı AppBar'ın altına al
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Soru Alanı
            Text(
              "Türkçesi:",
              style: textTheme.titleMedium
                  ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
            ),
            Text(
              _currentWord!.turkishTranslation,
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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

  // Zamanlayıcı (Steampunk Gauge/Gösterge gibi)
  PreferredSizeWidget _buildTimer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double progress = 1.0 - (_secondsElapsed / (_basePoints - _minPoints) / 2);
    progress = progress.clamp(0.0, 1.0); // 0 ile 1 arasında kalmasını sağla
    
    // Puanın ne zaman düşeceğini gösteren renk
    Color progressColor =
        progress > 0.5 ? colorScheme.primary : colorScheme.error;

    return PreferredSize(
      preferredSize: const Size.fromHeight(10.0),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
                Icon(Icons.timer, size: 16, color: colorScheme.onSurface.withOpacity(0.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cevap Kutuları (Daha belirgin)
  Widget _buildInputBoxes(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    List<Widget> boxes = [];
    for (int i = 0; i < _currentWord!.englishWord.length; i++) {
      boxes.add(
        GestureDetector(
          onTap: () {
            // Sadece doluysa geri sil
            if (i < _userInput.length) {
              _onInputBoxTapped(i);
            }
          },
          child: Container(
            width: 40,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface, // Antrasit yüzey
              border: Border.all(
                  color: colorScheme.primary.withOpacity(0.5), width: 1),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                )
              ],
            ),
            child: Center(
              child: Text(
                i < _userInput.length ? _userInput[i].toUpperCase() : "",
                style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
              ),
            ),
          ),
        ),
      );
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: boxes);
  }

  // Harf Çarkı (Steampunk Dişliler gibi)
  Widget _buildLetterWheel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final List<Widget> letters = [];
    double angleIncrement = (2 * pi) / _shuffledLetters.length;

    for (int i = 0; i < _shuffledLetters.length; i++) {
      double angle = angleIncrement * i;
      double x = _radius * cos(angle);
      double y = _radius * sin(angle);
      
      // Harfleri biraz döndürerek dişli hissi ver
      double rotationAngle = _letterAngles[i] ?? 0.0;

      letters.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: y + _radius, // Merkeze göre pozisyon
          left: x + _radius, // Merkeze göre pozisyon
          child: Transform.rotate(
            angle: rotationAngle * (pi / 180), // Dereceyi radyana çevir
            child: GestureDetector(
              onTap: () => _onLetterTapped(_shuffledLetters[i], i),
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  // Pirinç/Altın metalik görünüm
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.8),
                      colorScheme.primary,
                      colorScheme.secondary.withOpacity(0.7) // Bakır gölge
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.secondary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 5,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _shuffledLetters[i].toUpperCase(),
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.black, // Metalik üstüne koyu font
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
    return Container(
      width: _radius * 2 + 60, // Harflerin sığması için
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
              color: colorScheme.surface.withOpacity(0.5),
              border: Border.all(color: colorScheme.secondary, width: 4, style: BorderStyle.solid),
            ),
            child: Icon(Icons.settings, color: colorScheme.surface, size: 50), // Arka plan
          ),
          ...letters,
        ],
      ),
    );
  }
}