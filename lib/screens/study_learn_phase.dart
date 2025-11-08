// lib/screens/study_learn_phase.dart
import 'package:flutter/material.dart';
import 'package:word_learn/models/word_card.dart';

class StudyLearnPhase extends StatefulWidget {
  final List<WordCard> sessionWords;
  final VoidCallback onPhaseComplete;

  const StudyLearnPhase(
      {Key? key, required this.sessionWords, required this.onPhaseComplete})
      : super(key: key);

  @override
  _StudyLearnPhaseState createState() => _StudyLearnPhaseState();
}

class _StudyLearnPhaseState extends State<StudyLearnPhase> {
  int _currentIndex = 0;
  bool _isFlipped = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextCard() {
    if (_currentIndex < widget.sessionWords.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onPhaseComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Öğrenme Aşaması"),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.sessionWords.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _isFlipped = false;
          });
        },
        itemBuilder: (context, index) {
          final word = widget.sessionWords[index];
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFlipped = !_isFlipped;
                    });
                  },
                  child: AspectRatio(
                    aspectRatio: 3 / 4, // Kart oranı
                    child: Card(
                      // main.dart'taki CardTheme'i kullanacak
                      elevation: 8,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        // Kartın içine Steampunk kenarlık
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surface, // Antrasit yüzey
                        ),
                        child: Center(
                          child: Text(
                            _isFlipped
                                ? word.turkishTranslation
                                : word.englishWord,
                            textAlign: TextAlign.center,
                            style: _isFlipped
                                ? textTheme.headlineMedium
                                : textTheme.headlineLarge?.copyWith(
                                    color: colorScheme.primary, // Pirinç/Altın
                                    fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Çevirmek için dokun, geçmek için kaydır.",
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
                // İlerleme çubuğu
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, left: 32, right: 32),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / widget.sessionWords.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
                // "Sonraki" butonu (kaydırma alternatifi)
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
                      onPressed: _nextCard,
                      icon: Icon(Icons.arrow_forward),
                      label: Text(
                        _currentIndex == widget.sessionWords.length - 1
                            ? "Bitir"
                            : "Sonraki",
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}