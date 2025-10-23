import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/word_card.dart';
import '../widgets/flashcard.dart';
import '../widgets/mini_flashcard_stack.dart';
import '../services/save_service.dart';

class FlashcardPage extends StatefulWidget {
  final List<WordCard>? words;
  final bool continueFromLast;
  final String? loadSlot;

  const FlashcardPage({
    super.key,
    this.words,
    this.continueFromLast = false,
    this.loadSlot,
  });

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  List<WordCard> mainWords = [];
  List<WordCard> learnedWords = [];
  List<WordCard> unLearnedWords = [];
  int totalWords = 0;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void didUpdateWidget(FlashcardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.words != oldWidget.words) {
      _loadWords();
    }
  }

  Future<void> _loadWords() async {
    List<WordCard> wordsToLoad;
    if (widget.words != null) {
      wordsToLoad = widget.words!;
      setState(() {
        mainWords = wordsToLoad;
        learnedWords = [];
        unLearnedWords = [];
        totalWords = wordsToLoad.length;
      });
      return;
    }

    if (widget.continueFromLast) {
      final progress = await SaveService.loadLast();
      if (progress["main"]!.isNotEmpty || progress["learned"]!.isNotEmpty) {
        setState(() {
          mainWords = progress["main"]!;
          learnedWords = progress["learned"]!;
          unLearnedWords = progress["unlearned"]!;
          totalWords =
              mainWords.length + learnedWords.length + unLearnedWords.length;
        });
        return;
      }
    }

    if (widget.loadSlot != null) {
      final progress = await SaveService.loadSlot(widget.loadSlot!);
      setState(() {
        mainWords = progress["main"]!;
        learnedWords = progress["learned"]!;
        unLearnedWords = progress["unlearned"]!;
        totalWords =
            mainWords.length + learnedWords.length + unLearnedWords.length;
      });
      return;
    }

    final String jsonString = await rootBundle.loadString('assets/words.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final allWords = jsonList.map((e) => WordCard.fromJson(e)).toList();

    setState(() {
      mainWords = allWords;
      totalWords = mainWords.length;
    });
  }

  void _moveToLearned(WordCard word) {
    setState(() {
      mainWords.remove(word);
      learnedWords.add(word);
      _saveLast();
    });
  }

  void _moveToUnLearned(WordCard word) {
    setState(() {
      mainWords.remove(word);
      unLearnedWords.add(word);
      _saveLast();
    });
  }

  void _learnedWordsMoveToMain(WordCard word) {
    setState(() {
      learnedWords.remove(word);
      mainWords.add(word);
      _saveLast();
    });
  }

  void _unLearnedWordsMoveToMain(WordCard word) {
    setState(() {
      unLearnedWords.remove(word);
      mainWords.add(word);
      _saveLast();
    });
  }

  Future<void> _saveLast() async {
    await SaveService.saveLast(mainWords, learnedWords, unLearnedWords);
  }

  Future<void> _saveSlot() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kayıt Oluştur'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Kayıt Adı'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await SaveService.saveSlot(
                  nameController.text,
                  mainWords,
                  learnedWords,
                  unLearnedWords,
                );
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  double get _progress {
    if (totalWords == 0) return 0.0;
    return learnedWords.length / totalWords;
  }

  String get _progressText {
    return 'İlerleme: ${learnedWords.length}/$totalWords';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => _saveLast(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Kelime Kartları"),
          centerTitle: true,
          elevation: 4,
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.bookmark),
                onPressed: _saveSlot,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: mainWords.isEmpty && learnedWords.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    if (mainWords.isNotEmpty)
                      Center(
                        child: Flashcard(
                          key: ValueKey(mainWords[0].englishWord),
                          word: mainWords[0],
                          known: _moveToLearned,
                          unknown: _moveToUnLearned,
                          isLearned: false,
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          // build tamamlanınca anasayfaya dön
                          Future.microtask(() {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Tüm kelimeleri öğrendiniz! Ana sayfaya dönüldü.",
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          });

                          return const Center(
                            child:
                                CircularProgressIndicator(), // küçük bekleme animasyonu
                          );
                        },
                      ),
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _progressText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 20,
                      child: MiniFlashcardStack(
                        learnedWords: learnedWords,
                        onTap: _learnedWordsMoveToMain,
                      ),
                    ),
                    Positioned(
                      bottom: 5,
                      left: 20,
                      child: MiniFlashcardStack(
                        learnedWords: unLearnedWords,
                        onTap: _unLearnedWordsMoveToMain,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
