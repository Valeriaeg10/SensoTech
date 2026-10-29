import 'package:flutter/material.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';

// Escala Visual Analógica / Numérica del dolor (EVA–EVN), de 0 a 10.
// Solo se puede elegir un valor entre 0 y 10.
class EncuestaDolor extends StatelessWidget {
  final String pregunta;
  final int? valor;
  final ValueChanged<int> alCambiar;

  const EncuestaDolor({super.key, required this.pregunta, required this.valor, required this.alCambiar});

  static const maximo = 10;

  static String descripcion(int v) => switch (v) {
        0 => 'Sin dolor',
        <= 3 => 'Dolor leve',
        <= 6 => 'Dolor moderado',
        <= 9 => 'Dolor intenso',
        _ => 'Máximo dolor imaginable',
      };

  static Color color(int v) {
    const verde = Colores.verde, amarillo = Colores.amarillo, rojo = Colores.rojo;
    if (v <= 5) return Color.lerp(verde, amarillo, v / 5)!;
    return Color.lerp(amarillo, rojo, (v - 5) / 5)!;
  }

  static IconData cara(int v) => switch (v) {
        0 => Icons.sentiment_very_satisfied_rounded,
        <= 3 => Icons.sentiment_satisfied_rounded,
        <= 6 => Icons.sentiment_neutral_rounded,
        <= 8 => Icons.sentiment_dissatisfied_rounded,
        _ => Icons.sentiment_very_dissatisfied_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final v = valor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pregunta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Escala visual analógica (EVA): 0 = sin dolor, 10 = máximo dolor imaginable',
              style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
          const SizedBox(height: 16),
          // Cara y valor elegido
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: v == null
                  ? const Column(
                      key: ValueKey(-1),
                      children: [
                        Icon(Icons.touch_app_rounded, size: 56, color: Colores.textoSuave),
                        SizedBox(height: 4),
                        Text('Toca un número', style: TextStyle(color: Colores.textoSuave)),
                      ],
                    )
                  : Column(
                      key: ValueKey(v),
                      children: [
                        Icon(cara(v), size: 64, color: color(v)),
                        Text('$v / $maximo',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color(v))),
                        Text(descripcion(v), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Barra de color de 0 a 10
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: [color(0), color(5), color(10)]),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (_, c) {
            final ancho = (c.maxWidth - 10 * 4) / 11;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i <= maximo; i++)
                  GestureDetector(
                    onTap: () => alCambiar(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: ancho,
                      height: ancho.clamp(24.0, 40.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == i ? color(i) : Colores.blanco,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: v == i ? color(i) : Colores.borde, width: 1.5),
                      ),
                      child: Text('$i',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: v == i ? Colores.blanco : Colores.texto,
                          )),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sin dolor', style: TextStyle(color: Colores.textoSuave, fontSize: 11)),
              Text('Máximo', style: TextStyle(color: Colores.textoSuave, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
