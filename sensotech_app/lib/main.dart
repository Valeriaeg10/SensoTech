import 'package:flutter/material.dart';
import 'pantallas/perfiles_pantalla.dart';
import 'servicios/brazalete.dart';
import 'servicios/brazalete_simulado.dart';
import 'tema/tema_app.dart';

// Interruptor: true = datos falsos, false = brazalete real (más adelante)
const usarSimulado = true;

void main() {
  final Brazalete brazalete = BrazaleteSimulado(); // luego: usarSimulado ? ... : BrazaleteReal()
  runApp(SensoTechApp(brazalete: brazalete));
}

class SensoTechApp extends StatelessWidget {
  final Brazalete brazalete;

  const SensoTechApp({super.key, required this.brazalete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SensoTech',
      debugShowCheckedModeBanner: false, // quita la cinta "DEBUG"
      theme: temaApp(),
      home: PerfilesPantalla(brazalete: brazalete),
    );
  }
}
