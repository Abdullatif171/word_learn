// lib/screens/statistics_page.dart
import 'package:flutter/material.dart';
import 'package:word_learn/services/deck_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with AutomaticKeepAliveClientMixin {
  final DeckService _deckService = DeckService();
  Future<Map<String, int>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    // Sayfa her açıldığında verileri tazelemek için
    setState(() {
      _statsFuture = _deckService.getGlobalStatistics();
    });
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("İstatistiklerim"),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Veri bulunamadı."));
          }

          final stats = snapshot.data!;
          final int totalScore = stats['totalScore'] ?? 0;
          final int totalDecks = stats['totalDecks'] ?? 0;
          final int learnedWords = stats['learnedWords'] ?? 0;
          final int totalWords = stats['totalWords'] ?? 0;
          final double learnPercentage =
              (totalWords == 0) ? 0 : (learnedWords / totalWords);

          return RefreshIndicator(
            onRefresh: () async {
              _loadStats();
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildStatCard("Toplam Puan 🔥", totalScore.toString(),
                    Icons.star, Colors.orange),
                const SizedBox(height: 12),
                _buildStatCard("İndirilen Deste Sayısı 📚",
                    totalDecks.toString(), Icons.library_books, Colors.blue),
                const SizedBox(height: 12),
                _buildStatCard(
                    "Toplam Öğrenilen Kelime 🧠",
                    learnedWords.toString(),
                    Icons.school,
                    Colors.green),
                const SizedBox(height: 20),
                // Genel İlerleme
                Card(
                  elevation: 0,
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          "Genel Kelime Hakimiyeti",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: learnPercentage,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.deepPurpleAccent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$learnedWords / $totalWords Kelime",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Sayfa state'ini koru
  @override
  bool get wantKeepAlive => true;
}