// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:word_learn/screens/leaderboard_page.dart';
import 'package:word_learn/screens/profile_page.dart';
import 'package:word_learn/services/deck_service.dart';
import '../widgets/build_menu_card.dart'; // Bu widget'ı da güncelleyeceğiz
import 'library_page.dart';
// ... (HomePage State class - Değişiklik Yok) ...
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    MainPage(),
    const LibraryPage(),
    const LeaderboardPage(),
    const ProfilePage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void publicOnTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: publicOnTap,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: "Ana Sayfa"),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_books), label: "Kütüphane"),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: "Sıralama"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profilim"),
        ],
      ),
    );
  }
}

// --- MainPage (Ana Sayfa) İçeriği GÜNCELLENDİ ---
class MainPage extends StatelessWidget {
  MainPage({super.key});

  final DeckService _deckService = DeckService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final homePageState = context.findAncestorStateOfType<HomePageState>();

    return Scaffold(
      appBar: AppBar(
        // AppBar başlığı artık Steampunk fontuyla (main.dart'tan)
        title: const Text("WordLearn"),
        // AppBar arka planı 'surfaceColor' (Antrasit)
      ),
      body: Container(
        // Arka plana hafif bir desen veya doku eklenebilir,
        // şimdilik temadan gelen ana arka plan rengini kullanalım.
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Toplam Puan Göstergesi (Steampunk Temalı)
                FutureBuilder<int>(
                  future: _deckService.getUserScore(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                          child: CircularProgressIndicator(
                        color: colorScheme.primary, // Pirinç rengi
                      ));
                    }
                    return Card(
                      // CardTheme'den (main.dart) kenarlıklı stili alacak
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_border_purple500,
                                color: colorScheme.primary, // Pirinç/Altın
                                size: 30),
                            const SizedBox(width: 15),
                            Text(
                              "Toplam Puan: ${snapshot.data} 🔥",
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.primary, // Pirinç/Altın
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Menü Kartı (Temadan renk alacak)
                BuildMenuCard(
                  icon: Icons.library_books,
                  title: "Kütüphane",
                  subtitle: "Yeni desteler indir veya çalışmaya başla",
                  color: colorScheme.secondary, // Bakır rengi
                  onTap: () {
                    homePageState?.publicOnTap(1); // Kütüphane (index 1)
                  },
                ),

                const SizedBox(height: 20),

                BuildMenuCard(
                  icon: Icons.leaderboard,
                  title: "Sıralama",
                  subtitle: "Puanını diğerleriyle karşılaştır",
                  color: colorScheme.primary, // Pirinç/Altın rengi
                  onTap: () {
                    homePageState?.publicOnTap(2); // Sıralama (index 2)
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}