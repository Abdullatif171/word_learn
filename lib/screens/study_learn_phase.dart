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
    if (_currentIndex < widget.words.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      widget.onFinished();
    }
  }

  Widget _buildCard(WordCard word) {
    // ... (Bu metot değişmedi) ...
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

  // YENİ METOT: Erken çıkış onayı
  Future<bool> _onWillPop() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenme Turundan Çık'),
        content: const Text('Bu turu tamamlarsan mini oyuna geçeceksin. Şimdi çıkmak istediğine emin misin?'),
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
    return shouldPop ?? false; // null ise false dön
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.words.length) {
      return const Scaffold(body: Center(child: Text("Yükleniyor...")));
    }
    
    final word = widget.words[_currentIndex];

    // YENİ WIDGET: PopScope
    return PopScope(
      canPop: false, // Otomatik çıkışı engelle
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context); // Onaylanırsa manuel çık
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Aşama 1: Öğrenme Turu (Puan Yok)"),
          centerTitle: true,
          // automaticallyImplyLeading: false, // Geri tuşunu göstermek için bu satırı SİLİN
        ),
        body: Center(
          // ... (Body içeriği değişmedi) ...
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
      ),
    );
  }
}