import 'package:flutter/material.dart';

class GoodNightApp extends StatelessWidget {
  const GoodNightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoodNight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F3D8F),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('GoodNight 🌙')),
      ),
    );
  }
}
