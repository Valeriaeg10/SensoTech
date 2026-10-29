import 'package:flutter/material.dart';
import 'pantallas/arranque.dart';
import 'tema/tema_app.dart';

void main() {
  runApp(const SensoTechApp());
}

class SensoTechApp extends StatelessWidget {
  const SensoTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SensoTech',
      debugShowCheckedModeBanner: false, // quita la cinta "DEBUG"
      theme: temaApp(),
      home: const Arranque(), // login o inicio según la sesión
    );
  }
}
