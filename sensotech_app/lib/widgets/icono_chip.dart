import 'package:flutter/material.dart';
import '../tema/colores.dart';

// Ícono dentro de un cuadro azul suave
class IconoChip extends StatelessWidget {
  final IconData icono;
  final double tamano;

  const IconoChip({super.key, required this.icono, this.tamano = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: Colores.azulSuave,
        borderRadius: BorderRadius.circular(tamano * 0.3),
      ),
      child: Icon(icono, color: Colores.primario, size: tamano * 0.55),
    );
  }
}
