import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/home_screen.dart';

void main() {
  // Required before any Player/VideoController is created (initializes libmpv).
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const LiveTvApp());
}

class LiveTvApp extends StatelessWidget {
  const LiveTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'World Cup Live TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // pitch green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}