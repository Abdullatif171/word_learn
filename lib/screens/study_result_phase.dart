// lib/screens/study_result_phase.dart
import 'package:flutter/material.dart';
import 'package:word_learn/models/word_card.dart';

class StudyResultPhase extends StatelessWidget {
  final int score;
  final int totalQuestions; // <-- EKLENDİ
  final List<WordCard> correctWords;
  final List<WordCard> incorrectWords;
  final VoidCallback onFinished;

  const StudyResultPhase({
    super.key,
    required this.score,
    required this.totalQuestions, // <-- EKLENDİ
    required this.correctWords,
    required this.incorrectWords,
    required this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aşama 3: Oturum Sonucu"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      "Tebrikler!",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      // 'totalQuestions' artık burada kullanılıyor
                      "$totalQuestions kelimeden ${correctWords.length} tanesini doğru bildin.",
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Kazandığın Puan: +$score Puan 🔥",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            if (incorrectWords.isNotEmpty) ...[
              const Text(
                "Tekrar Edilecek Kelimeler",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: incorrectWords.length,
                  itemBuilder: (context, index) {
                    final word = incorrectWords[index];
                    return Card(
                      color: Colors.red[50],
                      child: ListTile(
                        title: Text(word.englishWord),
                        subtitle: Text(word.turkishTranslation),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const Spacer(), // Boşlukları doldur
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: onFinished,
              child: const Text("Devam Et"),
            ),
          ],
        ),
      ),
    );
  }
}