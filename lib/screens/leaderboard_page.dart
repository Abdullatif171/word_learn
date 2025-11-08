// lib/screens/leaderboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:word_learn/screens/home_page.dart';
import 'package:word_learn/services/firebase_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with AutomaticKeepAliveClientMixin {
      
  final FirebaseService _firebaseService = FirebaseService();
  Future<List<Map<String, dynamic>>>? _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    // Sayfa yüklendiğinde ve oturum açıksa veriyi çek
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      _loadLeaderboard();
    }
  }

  void _loadLeaderboard() {
    setState(() {
      _leaderboardFuture = _firebaseService.getLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = Provider.of<User?>(context); // Oturumu dinle

    // Oturum durumuna göre state'i güncelle
    if (user != null && _leaderboardFuture == null) {
      _loadLeaderboard();
    } else if (user == null && _leaderboardFuture != null) {
      setState(() {
        _leaderboardFuture = null; // Çıkış yapıldıysa listeyi temizle
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sıralama"),
      ),
      body: user == null
          ? _buildLoggedOutView(context)
          : _buildLeaderboardView(context),
    );
  }

  // Oturum kapalıyken gösterilecek
  Widget _buildLoggedOutView(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final homeState = context.findAncestorStateOfType<HomePageState>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard, 
              size: 80, 
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
            ),
            const SizedBox(height: 20),
            Text(
              "Sıralamayı görmek ve yarışmaya katılmak için giriş yapmalısın.",
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              child: const Text("Giriş Yap / Kaydol"),
              onPressed: () {
                // Kullanıcıyı Profilim (index 3) sayfasına yönlendir
                homeState?.publicOnTap(3); 
              },
            ),
          ],
        ),
      ),
    );
  }

  // Oturum açıkken sıralamayı göster
  Widget _buildLeaderboardView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Sıralama yüklenemedi: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Henüz sıralamada kimse yok."));
        }

        final users = snapshot.data!;
        
        return RefreshIndicator(
          onRefresh: () async {
            _loadLeaderboard();
          },
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isCurrentUser = user['uid'] == FirebaseAuth.instance.currentUser?.uid;

              return Card(
                color: isCurrentUser 
                    ? colorScheme.primary.withValues(alpha: 0.3) 
                    : colorScheme.surface,
                child: ListTile(
                  leading: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    user['displayName'] ?? 'Bilinmeyen Kullanıcı',
                    style: TextStyle(
                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: Text(
                    "${user['totalScore'] ?? 0} Puan 🔥",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}