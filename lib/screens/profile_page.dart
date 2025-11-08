// lib/screens/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:word_learn/services/auth_service.dart';
import 'package:word_learn/services/deck_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
      
  // statistics_page.dart'tan taşınan servis ve future
  final DeckService _deckService = DeckService();
  Future<Map<String, int>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // statistics_page.dart'tan taşındı
  void _loadStats() {
    setState(() {
      _statsFuture = _deckService.getGlobalStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Oturum durumunu korumak için

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = Provider.of<User?>(context); // Oturum durumunu dinle

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilim"),
        actions: [
          // Oturum açıksa Çıkış Yap butonu göster
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Çıkış Yap",
              onPressed: () async {
                await authService.signOut();
                // İstatistikleri de temizle (artık yerel değil)
                _loadStats(); 
              },
            )
        ],
      ),
      body: user == null
          ? _buildLoggedOutView(context, authService) // Oturum kapalıysa
          : _buildLoggedInView(context, user),      // Oturum açıksa
    );
  }

  // Oturum Kapalıyken Gösterilecek Arayüz
  Widget _buildLoggedOutView(BuildContext context, AuthService authService) {
    final textTheme = Theme.of(context).textTheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off, 
              size: 80, 
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5)
            ),
            const SizedBox(height: 20),
            Text(
              "İlerlemeni kaydetmek ve sıralamaya girmek için giriş yap.",
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.login), // Google ikonu da olabilir
              label: const Text("Google ile Giriş Yap"),
              onPressed: () async {
                await authService.signInWithGoogle();
                _loadStats(); // Giriş yaptıktan sonra istatistikleri yükle
              },
            ),
            const SizedBox(height: 20),
            Text("veya", style: textTheme.bodyMedium),
            const SizedBox(height: 20),
            // TODO: E-posta ile giriş/kayıt butonları buraya eklenebilir
            Text(
              "E-posta ile giriş/kayıt yakında eklenecek.",
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
  
  // Oturum Açıkken Gösterilecek Arayüz (Eski statistics_page.dart)
  Widget _buildLoggedInView(BuildContext context, User user) {
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Kullanıcı Bilgi Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user.photoURL != null 
                        ? NetworkImage(user.photoURL!) 
                        : null,
                    child: user.photoURL == null 
                        ? const Icon(Icons.person, size: 30) 
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? "Kullanıcı",
                          style: textTheme.titleLarge,
                        ),
                        Text(
                          user.email ?? "E-posta yok",
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Yerel İstatistiklerin",
            style: textTheme.headlineSmall,
          ),
          Text(
            "(Not: Puanların buluta taşınması bir sonraki adımdır)",
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 10),

          // statistics_page.dart'tan taşınan FutureBuilder
          FutureBuilder<Map<String, int>>(
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

              return Column(
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
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
                            backgroundColor: Colors.grey[700],
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary),
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
              );
            },
          ),
        ],
      ),
    );
  }

  // statistics_page.dart'tan taşınan yardımcı widget
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
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
                  style: TextStyle(fontSize: 14, color: Colors.white70),
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
  bool get wantKeepAlive => true; // State'i koru
}