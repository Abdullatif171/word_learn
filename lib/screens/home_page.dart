import 'package:flutter/material.dart';
import 'package:word_learn/screens/statistics_page.dart';
import 'package:word_learn/services/deck_service.dart';
import '../widgets/build_menu_card.dart';
import 'library_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

// 2. GÜNCELLEME: _HomePageState -> HomePageState
class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    MainPage(),
    const LibraryPage(),
    const StatisticsPage(),
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
    _pageController.jumpToPage(index); // Sayfayı anında değiştir
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
        // 4. GÜNCELLEME: _onTap -> publicOnTap
        onTap: publicOnTap,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: "Kütüphane",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "İstatistikler",
          ),
        ],
      ),
    );
  }
}

class MainPage extends StatelessWidget {
  MainPage({super.key});

  final DeckService _deckService = DeckService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final homePageState = context.findAncestorStateOfType<HomePageState>();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text("Kelime Kartları"),
        centerTitle: true,
        elevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Toplam Puan Göstergesi
              FutureBuilder<int>(
                future: _deckService.getUserScore(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return Card(
                    color: Colors.blue[50],
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Colors.orange, size: 30),
                          const SizedBox(width: 15),
                          Text(
                            "Toplam Puan: ${snapshot.data} 🔥",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              BuildMenuCard(
                icon: Icons.library_books,
                title: "Destelerine Göz At",
                subtitle: "Yeni desteler indir veya çalışmaya başla",
                color: Colors.blueAccent,
                onTap: () {
                  // BottomNavBar'da 1. indekse (Kütüphane) git
                  // 6. GÜNCELLEME: _onTap -> publicOnTap
                  homePageState?.publicOnTap(1);
                },
              ),

              const SizedBox(height: 40),

              Text(
                "🎯 Öğrenmek için kütüphaneden bir deste seç!",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
