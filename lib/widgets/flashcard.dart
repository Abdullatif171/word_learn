import 'package:flutter/material.dart';
import '../models/word_card.dart';

class Flashcard extends StatefulWidget {
  final WordCard word;
  final Function(WordCard) known;
  final Function(WordCard) unknown;
  final bool isLearned;

  const Flashcard({
    super.key,
    required this.word,
    required this.known,
    required this.unknown,
    required this.isLearned,
  });

  @override
  State<Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard> with SingleTickerProviderStateMixin {
  bool _showFront = true;

  void _flip() {
    setState(() {
      _showFront = !_showFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: Dismissible(
        key: ValueKey(widget.word),
        direction: DismissDirection.vertical,
        background: Container(
          alignment: Alignment.topCenter,
          child: Icon(Icons.delete, color: Colors.red, size: 50),
        ),
        secondaryBackground: Container(
          alignment: Alignment.bottomCenter,
          child: Icon(Icons.check, color: Colors.green, size: 70),
        ),
        onDismissed: (direction) {
          if (direction == DismissDirection.up) {
            // yukarı kaydırıldı → öğrenildi
            widget.known(widget.word);
            
          } else if (direction == DismissDirection.down) {
            // aşağı kaydırıldı → öğrenilmedi
            widget.unknown(widget.word);
            
          }
        },
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: _showFront ? Colors.blue.shade200 : Colors.blue.shade500,
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            height: 350,
            child: Center(
              child: _showFront
                  ? Text(
                      widget.word.englishWord,
                      key: ValueKey('front-${widget.word.englishWord}'),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      widget.word.turkishTranslation,
                      key: ValueKey('back-${widget.word.englishWord}'),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
