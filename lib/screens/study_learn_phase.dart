// lib/screens/study_learn_phase.dart
import 'package:flutter/material.dart';
import 'package:word_learn/models/word_card.dart';

class StudyLearnPhase extends StatefulWidget {
  final List<WordCard> words;
  final VoidCallback onFinished;

  const StudyLearnPhase({
    super.key,
    required this.words,
    required this.onFinished,
  });

  @override
  State<StudyLearnPhase> createState() => _StudyLearnPhaseState();
}

class _StudyLearnPhaseState extends State<StudyLearnPhase> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  void _nextCard(DismissDirection direction) {
    // Puanlama yok, sadece ilerle
    if (_currentIndex < widget.words.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false; // Yeni kartta ön yüzü göster
      });
    } else {
      // 10 kelime bitti
      widget.onFinished();
    }
  }

  Widget _buildCard(WordCard word) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isFlipped = !_isFlipped;
        });
      },
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.5,
          padding: const EdgeInsets.all(24.0),
          alignment: Alignment.center,
          child: Text(
            _isFlipped ? word.turkishTranslation : word.englishWord,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kelimeler bitmişse (güvenlik kontrolü)
    if (_currentIndex >= widget.words.length) {
      return const Scaffold(body: Center(child: Text("Yükleniyor...")));
    }
    
    final word = widget.words[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aşama 1: Öğrenme Turu (Puan Yok)"),
        centerTitle: true,
        automaticallyImplyLeading: false, // Geri gitmeyi engelle
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Kartı çevirmek için dokun, geçmek için kaydır.",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Dismissible(
                key: ValueKey(word.englishWord),
                onDismissed: _nextCard,
                child: _buildCard(word),
              ),
              const SizedBox(height: 20),
              Text(
                "${_currentIndex + 1} / ${widget.words.length}",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}