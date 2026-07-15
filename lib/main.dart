import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/complete_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Restore token if app was killed mid-flow
  final token = await StorageService.getUploadToken();
  if (token != null) {
    ApiService.setUploadToken(token);
  }

  final isRegistered = await StorageService.isRegistered();

  runApp(SeboApp(isRegistered: isRegistered));
}

class SeboApp extends StatelessWidget {
  final bool isRegistered;
  const SeboApp({super.key, required this.isRegistered});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小怪兽',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.light,
        ),
        fontFamily: 'PingFang SC',
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
          ),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
        ),
      ),
      home: isRegistered ? const CompleteScreen() : const OnboardingScreen(),
    );
  }
}
