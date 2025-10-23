import 'package:flutter/material.dart';
import '../widgets/build_menu_card.dart';
import 'flashcard_page.dart';
import 'library_page.dart';
import 'saves_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = const [
    MainPage(),
    LibraryPage(), // Artık Kütüphane sayfası
    SavesPage()
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index); // Sayfayı anında değiştir
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PageView kullanarak state'lerin korunmasını sağlıyoruz
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
        onTap: _onTap, // Değiştirildi
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: "Kütüphane", // Adı güncellendi
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Geçmiş"),
        ],
      ),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // HomePage'deki PageController'ı bulmak için
    final homePageState = context.findAncestorStateOfType<_HomePageState>();

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
              Text(
                "📚 Öğrenmeye Hazır mısın?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              // "Yeni Başla" kaldırıldı, çünkü 'assets/words.json' artık ana veri kaynağı değil.
              
              BuildMenuCard(
                icon: Icons.library_books,
                title: "Kütüphaneye Göz At",
                subtitle: "Yeni desteler indir veya indirdiklerine çalış",
                color: Colors.blueAccent,
                onTap: () {
                  // BottomNavBar'da 1. indekse (Kütüphane) git
                  homePageState?._onTap(1);
                },
              ),
              
              const SizedBox(height: 20),

              BuildMenuCard(
                icon: Icons.refresh,
                title: "Devam Et",
                subtitle: "Son bıraktığın yerden hemen devam et",
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const FlashcardPage(continueFromLast: true),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              Text(
                "🎯 Her gün biraz ilerle, kelimeler seninle kalsın!",
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