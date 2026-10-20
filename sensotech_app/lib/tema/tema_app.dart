import 'package:flutter/material.dart';
import 'colores.dart';

// Tema general de la app
ThemeData temaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Colores.primario,
    primary: Colores.primario,
    surface: Colores.fondo,
    onSurface: Colores.texto,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Colores.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colores.fondo,
      foregroundColor: Colores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colores.texto,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colores.primario,
        foregroundColor: Colores.blanco,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colores.primario,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Colores.primario),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

// Tarjeta blanca con sombra suave
BoxDecoration decoracionTarjeta() {
  return BoxDecoration(
    color: Colores.blanco,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colores.borde),
    boxShadow: const [
      BoxShadow(color: Color(0x0D1B2B3A), blurRadius: 16, offset: Offset(0, 4)),
    ],
  );
}
