import 'package:flutter/material.dart';
import '../tema/colores.dart';

// Logo: brazalete con pantalla y pulso, sobre fondo azul
class LogoSensoTech extends StatelessWidget {
  final double tamano;
  final bool conNombre;

  const LogoSensoTech({super.key, this.tamano = 52, this.conNombre = true});

  @override
  Widget build(BuildContext context) {
    final icono = SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(painter: _PintorLogo()),
    );
    if (!conNombre) return icono;

    return Row(
      children: [
        icono,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                children: [
                  TextSpan(text: 'Senso', style: TextStyle(color: Colores.primarioOscuro)),
                  TextSpan(text: 'Tech', style: TextStyle(color: Colores.primario)),
                ],
              ),
            ),
            const Text('Prevención y rehabilitación del STC',
                style: TextStyle(fontSize: 12, color: Colores.textoSuave)),
          ],
        ),
      ],
    );
  }
}

class _PintorLogo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final caja = Offset.zero & size;

    // Fondo con degradado
    final fondo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5AB0FF), Colores.primarioOscuro],
      ).createShader(caja);
    canvas.drawRRect(RRect.fromRectAndRadius(caja, Radius.circular(s * 0.28)), fondo);

    // Banda del brazalete (vista en perspectiva)
    final banda = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..color = Colores.blanco.withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.5, s * 0.44), width: s * 0.66, height: s * 0.34),
      banda,
    );

    // Pantalla al frente
    final pantalla = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(s * 0.5, s * 0.62), width: s * 0.44, height: s * 0.27),
      Radius.circular(s * 0.07),
    );
    canvas.drawRRect(pantalla, Paint()..color = Colores.blanco);

    // Pulso dentro de la pantalla
    final y = s * 0.62;
    final pulso = Path()
      ..moveTo(s * 0.33, y)
      ..lineTo(s * 0.42, y)
      ..lineTo(s * 0.46, y - s * 0.07)
      ..lineTo(s * 0.51, y + s * 0.07)
      ..lineTo(s * 0.55, y - s * 0.03)
      ..lineTo(s * 0.58, y)
      ..lineTo(s * 0.67, y);
    canvas.drawPath(
      pulso,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colores.primario,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
