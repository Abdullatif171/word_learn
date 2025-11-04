// lib/screens/study_session_page.dart
import 'package:flutter/material.dart';
import 'package:word_learn/models/deck_model.dart';
import 'package:word_learn/models/word_card.dart';
import 'package:word_learn/screens/study_learn_phase.dart';
// import 'package:word_learn/screens/study_test_phase.dart'; // YERİNE AŞAĞIDAKİ GELDİ
import 'package:word_learn/screens/study_game_phase.dart'; // YENİ OYUNU İÇE AKTAR
import 'package:word_learn/screens/study_result_phase.dart';
import 'package:word_learn/services/deck_service.dart';

// Oturumun 3 aşamasını tanımlayan enum
enum StudyPhase { Loading, Learn, Test, Result }

class StudySessionPage extends StatefulWidget {
  final Deck deck;
  const StudySessionPage({super.key, required this.deck});

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  final DeckService _deckService = DeckService();
  StudyPhase _currentPhase = StudyPhase.Loading;

  List<WordCard> _allDeckWords = [];
  List<WordCard> _sessionWords = []; // Çalışılacak 10 kelime
  
  // Sonuçlar
  int _sessionScore = 0;
  final List<WordCard> _correctWords = [];
  final List<WordCard> _incorrectWords = [];

  @override
  void initState() {
    super.initState();
    _loadWordsForSession();
  }

  Future<void> _loadWordsForSession() async {
    // Destenin tüm kelimelerini yerel dosyadan yükle
    _allDeckWords = await _deckService.loadDeckFromLocal(widget.deck.id);

    // Henüz öğrenilmemiş (reviewIntervalDays == 0) veya tekrar zamanı gelmiş kelimeleri bul
    final now = DateTime.now();
    final List<WordCard> dueWords = _allDeckWords.where((word) {
      if (word.reviewIntervalDays == 0) return true; // Yeni kelime
      if (word.nextReviewTimestamp == null) return false;
      try {
        return DateTime.parse(word.nextReviewTimestamp!).isBefore(now);
      } catch (e) {
        return true; // Hatalı tarih varsa, çalışılsın
      }
    }).toList();

    dueWords.shuffle();
    
    // O oturum için 10 kelime seç
    _sessionWords = dueWords.take(10).toList();

    if (_sessionWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu destede çalışılacak yeni kelime kalmamış! 🥳")),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _currentPhase = StudyPhase.Learn;
    });
  }

  // Aşama 1 (Öğrenme) bittiğinde çağrılır
  void _onLearnFinished() {
    setState(() {
      _currentPhase = StudyPhase.Test;
    });
  }

  // Aşama 2 (Test) bittiğinde çağrılır
  Future<void> _onTestFinished(int score, List<WordCard> correct, List<WordCard> incorrect) async {
    // 1. Sonuçları kaydet
    setState(() {
      _sessionScore = score;
      _correctWords.addAll(correct);
      _incorrectWords.addAll(incorrect);
      _currentPhase = StudyPhase.Result;
    });

    // 2. Puanı ve ilerlemeyi veritabanına yaz
    try {
      await _deckService.updateUserScore(_sessionScore);
      await _deckService.updateWordsProgress(widget.deck.id, _correctWords, _incorrectWords);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("İlerleme kaydedilirken hata oluştu: $e")),
        );
      }
    }
  }

  // Aşama 3 (Sonuç) bittiğinde çağrılır
  void _onResultFinished() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentPhase) {
      case StudyPhase.Loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case StudyPhase.Learn:
        return StudyLearnPhase(
          words: _sessionWords,
          onFinished: _onLearnFinished,
        );
      case StudyPhase.Test:
        // ---------- GÜNCELLEME BURADA ----------
        // StudyTestPhase yerine StudyGamePhase çağırıyoruz.
        // Artık 'allDeckWords' parametresine gerek yok.
        return StudyGamePhase(
          wordsToTest: _sessionWords,
          onFinished: _onTestFinished,
        );
        // ---------- GÜNCELLEME BİTTİ ----------
      case StudyPhase.Result:
        // Hiç kelime test edilmediyse (örn. hepsi 3 harften kısaydı)
        // direkt geri dön
        if (_sessionWords.isEmpty) {
          Future.microtask(() => Navigator.of(context).pop());
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        return StudyResultPhase(
          score: _sessionScore,
          totalQuestions: _sessionWords.length,
          correctWords: _correctWords,
          incorrectWords: _incorrectWords,
          onFinished: _onResultFinished,
        );
    }
  }
}