// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart'; // Yeni tema için eklendi
import 'package:provider/provider.dart'; // Eklendi
import 'package:firebase_auth/firebase_auth.dart'; // Eklendi

import 'screens/home_page.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart'; // Oluşturacağımız yeni servis

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Antrasit & Steampunk Renk Paleti
  static const Color primaryColor = Color(0xFFD4AF37); // Pirinç/Altın Vurgu
  static const Color secondaryColor = Color(0xFF8B4513); // Bakır/Ahşap
  static const Color backgroundColor = Color(0xFF2C3E50); // Koyu Antrasit Arka Plan
  static const Color surfaceColor = Color(0xFF34495E); // Antrasit Yüzey (Kartlar)
  static const Color textColor = Color(0xFFECF0F1); // Açık Gri Metin
  
  // Yeni Steampunk Teması
  ThemeData _buildSteampunkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      
      // Google Fonts kullanarak temaya uygun bir font seçiyoruz
      textTheme: GoogleFonts.ebGaramondTextTheme( // 'EBGaramond' serif fontu steampunk hissiyatı verir
        ThemeData.dark().textTheme,
      ).copyWith(
        bodyMedium: TextStyle(color: textColor),
        bodyLarge: TextStyle(color: textColor),
        titleMedium: TextStyle(color: textColor),
        headlineSmall: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      ),
      
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: Colors.black,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: textColor,
        surfaceContainerHighest: backgroundColor, // HomePage'deki arka plan için
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: primaryColor,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: GoogleFonts.ebGaramond(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      
      // --- HATA BURADAYDI: CardTheme -> CardThemeData ---
      cardTheme: CardThemeData( // DÜZELTİLDİ
        color: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Uygulamayı MultiProvider ile sararak Auth servisini sağlıyoruz
    return MultiProvider(
      providers: [
        // Auth servisi oluşturuluyor
        Provider<AuthService>(
          create: (_) => AuthService(FirebaseAuth.instance),
        ),
        // Auth servisinden gelen kullanıcı oturum durumunu dinliyoruz
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'WordLearn Steampunk',
        theme: _buildSteampunkTheme(), // Yeni temamızı uyguluyoruz
        home: const HomePage(), // HomePage olarak kalıyor, iç yapısı değişecek
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}