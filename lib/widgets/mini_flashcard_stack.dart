import 'package:flutter/material.dart';
import '../models/word_card.dart';

class MiniFlashcardStack extends StatelessWidget {
  final List<WordCard> learnedWords;
  final Function(WordCard) onTap;

  const MiniFlashcardStack({
    super.key,
    required this.learnedWords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: learnedWords.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isTopCard = index == learnedWords.length - 1;
          return MiniFlashcard(
            word: word,
            onTap: isTopCard ? () => onTap(word) : null,
          );
        }).toList(),
      ),
    );
  }
}

class MiniFlashcard extends StatelessWidget {
  final WordCard word;
  final VoidCallback? onTap;

  const MiniFlashcard({
    super.key,
    required this.word,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        color: Colors.blue.shade200,
        child: Container(
          width: 200,
          height: 80,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            word.englishWord,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
