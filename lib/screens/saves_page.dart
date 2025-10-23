import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/save_service.dart';
import 'flashcard_page.dart';
import '../models/word_card.dart';

class SavesPage extends StatefulWidget {
  const SavesPage({super.key});

  @override
  State<SavesPage> createState() => _SavesPageState();
}

class _SavesPageState extends State<SavesPage> {
  Map<String, dynamic> saves = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaves();
  }

  Future<void> _loadSaves() async {
    setState(() => _isLoading = true);
    try {
      final data = await SaveService.loadAllSlots();
      setState(() => saves = data);
      if (!mounted) return;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kayıtlar yüklenirken bir hata oluştu: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kaydı Sil"),
        content: const Text("Bu kaydı silmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (result == true) _deleteSave(name);
  }

  Future<void> _deleteSave(String name) async {
    try {
      await SaveService.deleteSlot(name);
      await _loadSaves();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$name silindi")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Silme işlemi başarısız: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text("Kayıtlar"),
        centerTitle: true,
        elevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSaves,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : saves.isEmpty
          ? const Center(
              child: Text(
                "Henüz kayıt yok",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: saves.keys.length,
              itemBuilder: (context, index) {
                final saveName = saves.keys.toList()[index];
                final save = saves[saveName];
                return _buildSaveCard(context, saveName, save);
              },
            ),
    );
  }

  Widget _buildSaveCard(
    BuildContext context,
    String name,
    Map<String, dynamic> save,
  ) {
    final date = save["timestamp"] != null
        ? DateFormat('dd.MM.yyyy').format(DateTime.parse(save["timestamp"]))
        : "Bilinmiyor";

    final mainCount = (save['main'] as List?)?.length ?? 0;
    final learnedCount = (save['learned'] as List?)?.length ?? 0;
    final progress = mainCount + learnedCount > 0
        ? (learnedCount / (mainCount + learnedCount) * 100)
        : 0;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final updatedData = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FlashcardPage(loadSlot: name)),
          );

          if (updatedData != null && updatedData is Map) {
            final List<WordCard> mainWords = (updatedData['main'] as List)
                .map((e) => WordCard.fromJson(e))
                .toList();
            final List<WordCard> learnedWords = (updatedData['learned'] as List)
                .map((e) => WordCard.fromJson(e))
                .toList();
            final List<WordCard> unLearnedWords = (updatedData['unlearned'] as List)
                .map((e) => WordCard.fromJson(e))
                .toList();

            await SaveService.saveSlot(name, mainWords, learnedWords, unLearnedWords);
            _loadSaves();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("'$name' kaydı güncellendi!")),
            );
          } else {
            _loadSaves();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.indigo.withValues(alpha: 0.8), Colors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.save, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Son oynama: $date",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent,
                      ),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "%${progress.toStringAsFixed(0)} tamamlandı",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, name),
                icon: const Icon(Icons.delete, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
