import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const KoreaFestivalApp());
}

class KoreaFestivalApp extends StatelessWidget {
  const KoreaFestivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대한민국 축제 지도',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const HomeScreen(),
    );
  }
}
