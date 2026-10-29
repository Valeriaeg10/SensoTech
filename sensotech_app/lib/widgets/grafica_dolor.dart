import 'package:flutter/material.dart';
import '../modelos/rutina.dart';
import '../tema/colores.dart';

const colorDolorAntes = Color(0xFFE07A5F);
const colorDolorDespues = Color(0xFF2B7DE9);

// Barras dobles por sesión: dolor antes y después (EVA 0–10)
class GraficaDolor extends StatelessWidget {
  final List<SesionRehab> sesiones; // de la más vieja a la más reciente

  const GraficaDolor({super.key, required this.sesiones});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: CustomPaint(size: Size.infinite, painter: _PintorDolor(sesiones)),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 14,
          children: [
            LeyendaColor(color: colorDolorAntes, texto: 'Antes de la sesión'),
            LeyendaColor(color: colorDolorDespues, texto: 'Después de la sesión'),
          ],
        ),
      ],
    );
  }
}

class LeyendaColor extends StatelessWidget {
  final Color color;
  final String texto;

  const LeyendaColor({super.key, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
      ],
    );
  }
}

class _PintorDolor extends CustomPainter {
  final List<SesionRehab> s;

  _PintorDolor(this.s);

  static const _izq = 26.0, _abajo = 20.0, _arriba = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width - _izq;
    final alto = size.height - _abajo - _arriba;
    double y(num v) => _arriba + alto * (1 - v / 10);

    final rejilla = Paint()
      ..color = Colores.borde
      ..strokeWidth = 1;
    for (var g = 0; g <= 10; g += 2) {
      canvas.drawLine(Offset(_izq, y(g)), Offset(size.width, y(g)), rejilla);
      _texto(canvas, '$g', Offset(_izq - 6, y(g)), derecha: true);
    }
    if (s.isEmpty) return;

    final columna = ancho / s.length;
    final barra = (columna * 0.32).clamp(3.0, 14.0);
    for (var i = 0; i < s.length; i++) {
      final cx = _izq + columna * (i + 0.5);
      void dibujar(int? v, double dx, Color c) {
        if (v == null) return;
        final r = RRect.fromLTRBAndCorners(
          cx + dx - barra / 2,
          y(v.clamp(0, 10)) - (v == 0 ? 2 : 0),
          cx + dx + barra / 2,
          y(0),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(r, Paint()..color = c);
      }

      dibujar(s[i].dolorAntes, -barra / 2 - 1, colorDolorAntes);
      dibujar(s[i].dolorDespues, barra / 2 + 1, colorDolorDespues);
      _texto(canvas, '${i + 1}', Offset(cx, size.height - _abajo / 2));
    }
  }

  void _texto(Canvas canvas, String t, Offset pos, {bool derecha = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: const TextStyle(color: Colores.textoSuave, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(derecha ? pos.dx - tp.width : pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorDolor old) => old.s != s;
}
