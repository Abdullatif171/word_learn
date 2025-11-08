// lib/screens/study_session_page.dart
import 'package:flutter/material.dart';
import 'package:word_learn/models/deck_model.dart';
import 'package:word_learn/models/word_card.dart';
import 'package:word_learn/screens/study_game_phase.dart';
import 'package:word_learn/screens/study_learn_phase.dart';
import 'package:word_learn/screens/study_result_phase.dart';
import 'package:word_learn/services/deck_service.dart';
import 'package:word_learn/services/firebase_service.dart'; // <-- YENİ IMPORT

enum StudyPhase { learning, game, results }

class StudySessionPage extends StatefulWidget {
  final Deck deck; 
  final List<WordCard> words;

  const StudySessionPage({
    super.key,
    required this.deck,
    required this.words,
  });

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  StudyPhase _currentPhase = StudyPhase.learning;
  final DeckService _deckService = DeckService();
  final FirebaseService _firebaseService = FirebaseService(); // <-- YENİ INSTANCE

  List<WordCard> _sessionWords = [];
  final List<WordCard> _allDeckWords = []; 

  List<WordCard> _correctAnswers = [];
  List<WordCard> _incorrectAnswers = [];
  int _sessionScore = 0;

  @override
  void initState() {
    super.initState();
    _allDeckWords.addAll(widget.words); 
    _prepareSessionWords();
  }

  void _prepareSessionWords() {
    // 1. Tekrar zamanı gelen kelimeleri (due) bul
    final now = DateTime.now();
    final List<WordCard> dueWords = _allDeckWords.where((word) {
      if (word.nextReviewTimestamp == null) return false;
      final reviewDate = DateTime.tryParse(word.nextReviewTimestamp!);
      return reviewDate != null && reviewDate.isBefore(now);
    }).toList();

    // 2. Yeni kelimeleri (öğrenilmemiş) bul
    final List<WordCard> newWords = _allDeckWords
        .where((word) => word.reviewIntervalDays == 0)
        .toList();

    // 3. Oturum kelimelerini birleştir (önce zamanı gelenler, sonra yeniler)
    dueWords.shuffle();
    newWords.shuffle();
    
    _sessionWords = (dueWords + newWords).toSet().take(10).toList();
    
    // Eğer 10 kelime bulunamazsa, öğrenilmiş kelimelerden rastgele ekle
    if (_sessionWords.length < 10) {
      final List<WordCard> remainingWords = _allDeckWords
          .where((word) => !_sessionWords.contains(word))
          .toList();
      remainingWords.shuffle();
      _sessionWords.addAll(remainingWords.take(10 - _sessionWords.length));
    }

    // Oturum için yeterli kelime yoksa öğrenme aşamasına geç
    if (_sessionWords.isEmpty) {
      setState(() {
        _currentPhase = StudyPhase.learning;
      });
    }
  }

  // Aşama 1 bittiğinde (Learn -> Game)
  void _onLearnComplete() {
    if (_sessionWords.isEmpty) {
      // Öğrenecek kelime yoksa direkt çık
      Navigator.pop(context);
    } else {
      setState(() {
        _currentPhase = StudyPhase.game;
      });
    }
  }

  // Aşama 2 bittiğinde (Game -> Results)
  void _onGameComplete(
      List<WordCard> correct, List<WordCard> incorrect, int score) async {
    
    // --- GÜNCELLEME BAŞLANGICI ---
    
    // 1. Yerel puanı (SharedPreferences) güncelle (ProfilePage'in hızlıca görmesi için)
    await _deckService.updateUserScore(score);
    
    // 2. Firebase puanını (Firestore) güncelle (LeaderboardPage için)
    try {
      await _firebaseService.updateUserScoreInFirestore(score);
    } catch (e) {
      // Hata olursa (örn. internet yoksa) kullanıcıyı bilgilendir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Puan sunucuya yüklenemedi: $e"))
        );
      }
    }

    // 3. Kelime ilerlemesini (SRS) yerel olarak kaydet
    await _deckService.updateWordsProgress(widget.deck.id, correct, incorrect);
    // --- GÜNCELLEME SONU ---

    setState(() {
      _correctAnswers = correct;
      _incorrectAnswers = incorrect;
      _sessionScore = score;
      _currentPhase = StudyPhase.results;
    });
  }

  // Aşama 3 bittiğinde (Results -> Çıkış)
  void _onResultComplete() {
    Navigator.pop(context); // Kütüphane sayfasına geri dön
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentPhase) {
      case StudyPhase.learning:
        return StudyLearnPhase(
          sessionWords: _sessionWords.isEmpty ? _allDeckWords.take(10).toList() : _sessionWords,
          onPhaseComplete: _onLearnComplete,
        );
      case StudyPhase.game:
        return StudyGamePhase(
          sessionWords: _sessionWords,
          onSessionComplete: _onGameComplete,
        );
      case StudyPhase.results:
        return StudyResultPhase(
          score: _sessionScore,
          correctWords: _correctAnswers,
          incorrectWords: _incorrectAnswers,
          totalQuestions: _sessionWords.length,
          onFinished: _onResultComplete, 
        );
    }
  }
}