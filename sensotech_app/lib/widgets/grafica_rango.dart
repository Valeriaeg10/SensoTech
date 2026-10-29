import 'dart:math';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/rutina.dart';
import '../tema/colores.dart';

// Color fijo para cada movimiento
const coloresMovimiento = {
  TipoEjercicio.flexion: Color(0xFF2B7DE9),
  TipoEjercicio.extension: Color(0xFF12A4A0),
  TipoEjercicio.radial: Color(0xFFE8A800),
  TipoEjercicio.cubital: Color(0xFF8A63D2),
};

// Gráfica de líneas: ángulo máximo de cada movimiento por sesión
class GraficaRango extends StatelessWidget {
  final List<SesionRehab> sesiones; // de la más vieja a la más reciente
  final Set<TipoEjercicio> visibles;

  const GraficaRango({super.key, required this.sesiones, required this.visibles});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PintorRango(sesiones, visibles),
      ),
    );
  }
}

class _PintorRango extends CustomPainter {
  final List<SesionRehab> s;
  final Set<TipoEjercicio> visibles;

  _PintorRango(this.s, this.visibles);

  static const _izq = 34.0, _abajo = 24.0, _arriba = 8.0, _der = 8.0;
  static const _maxY = 90.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width - _izq - _der;
    final alto = size.height - _abajo - _arriba;
    Offset punto(int i, double v) => Offset(
          _izq + (s.length == 1 ? ancho / 2 : ancho * i / (s.length - 1)),
          _arriba + alto * (1 - v / _maxY),
        );

    // Rejilla cada 15°
    final rejilla = Paint()
      ..color = Colores.borde
      ..strokeWidth = 1;
    for (var g = 0; g <= 90; g += 15) {
      final y = _arriba + alto * (1 - g / _maxY);
      canvas.drawLine(Offset(_izq, y), Offset(size.width - _der, y), rejilla);
      _texto(canvas, '$g°', Offset(_izq - 6, y), alinearDerecha: true);
    }
    if (s.isEmpty) return;

    // Eje X: número de sesión
    for (var i = 0; i < s.length; i++) {
      final x = punto(i, 0).dx;
      _texto(canvas, '${i + 1}', Offset(x, size.height - _abajo / 2));
    }

    for (final t in TipoEjercicio.values.where(visibles.contains)) {
      final color = coloresMovimiento[t]!;
      final camino = Path();
      for (var i = 0; i < s.length; i++) {
        final p = punto(i, min(s[i].maximo(t), _maxY));
        if (i == 0) {
          camino.moveTo(p.dx, p.dy);
        } else {
          camino.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        camino,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      for (var i = 0; i < s.length; i++) {
        final p = punto(i, min(s[i].maximo(t), _maxY));
        canvas.drawCircle(p, 3.5, Paint()..color = Colores.blanco);
        canvas.drawCircle(
          p,
          3.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      }
    }
  }

  void _texto(Canvas canvas, String t, Offset pos, {bool alinearDerecha = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: const TextStyle(color: Colores.textoSuave, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = alinearDerecha ? pos.dx - tp.width : pos.dx - tp.width / 2;
    tp.paint(canvas, Offset(x, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorRango old) => old.s != s || old.visibles != visibles;
}

// Barra horizontal de un movimiento:
// barra completa = rango normal · tono claro = al inicio · tono fuerte = hoy
class BarraRango extends StatelessWidget {
  final TipoEjercicio tipo;
  final double base; // primera medición
  final double actual; // última medición
  final bool comparar; // false si solo hay una sesión

  const BarraRango({super.key, required this.tipo, required this.base, required this.actual, this.comparar = true});

  @override
  Widget build(BuildContext context) {
    final ref = rangoReferencia[tipo]!;
    final color = coloresMovimiento[tipo]!;
    final mejora = actual - base;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tipo.texto, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${actual.round()}°', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(' de ${ref.round()}°', style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 14,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(color: Colores.azulSuave, borderRadius: BorderRadius.circular(7)),
                ),
                Container(
                  width: w * (actual / ref).clamp(0.0, 1.0).toDouble(),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                ),
                if (comparar)
                  Container(
                    width: w * (base / ref).clamp(0.0, 1.0).toDouble(),
                    decoration: BoxDecoration(
                      color: Colores.blanco.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          comparar
              ? 'Al inicio ${base.round()}° → hoy ${actual.round()}° '
                  '(${mejora >= 0 ? 'ganó' : 'perdió'} ${mejora.abs().round()}°) · '
                  '${(actual * 100 / ref).round()} % del rango normal'
              : 'Primera medición · ${(actual * 100 / ref).round()} % del rango normal',
          style: TextStyle(
            color: !comparar || mejora.abs() < 0.5 ? Colores.textoSuave : (mejora > 0 ? Colores.verde : Colores.rojo),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Explicación de cómo leer las barras
class LeyendaRango extends StatelessWidget {
  const LeyendaRango({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: Colores.textoSuave),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'La barra completa es el rango normal de la muñeca. '),
              TextSpan(
                text: 'Tono claro',
                style: TextStyle(color: Colores.primario.withValues(alpha: 0.6), fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: ': hasta dónde llegaba al inicio. '),
              const TextSpan(text: 'Tono fuerte', style: TextStyle(color: Colores.primario, fontWeight: FontWeight.w700)),
              const TextSpan(text: ': hasta dónde llega hoy.'),
            ]),
            style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
