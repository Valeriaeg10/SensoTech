import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'pantallas/arranque.dart';
import 'tema/tema_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // conecta con Firebase
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
