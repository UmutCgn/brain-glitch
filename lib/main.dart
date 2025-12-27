import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/game_screen.dart'; // Oyun ekranını buradan çağırıyoruz

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const CandyBrainApp());
}

class CandyBrainApp extends StatelessWidget {
  const CandyBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brain Glitch',
      theme: ThemeData(
        fontFamily: 'Arial Rounded',
        scaffoldBackgroundColor: const Color(0xFFFFC0CB),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
        ),
      ),
      home: const GameScreen(),
    );
  }
}