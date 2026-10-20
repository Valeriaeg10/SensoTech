import 'dart:math';
import 'package:flutter/material.dart';
import '../tema/colores.dart';

// Qué vista dibujar
enum TipoVista { lateral, superior }

// Dibujo del antebrazo y la mano con las dos IMU
class VistaBrazo extends StatelessWidget {
  final TipoVista vista;
  final double flexion;
  final double desviacion;
  final double antebrazo;
  final Color colorEstado;

  const VistaBrazo({
    super.key,
    required this.vista,
    required this.flexion,
    required this.desviacion,
    required this.antebrazo,
    required this.colorEstado,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1.7,
        child: CustomPaint(
          painter: _PintorBrazo(
            vista: vista,
            flexion: flexion,
            desviacion: desviacion,
            antebrazo: antebrazo,
            colorEstado: colorEstado,
          ),
        ),
      ),
    );
  }
}

// Un tramo del cuerpo: línea gruesa entre dos puntos
class _Tramo {
  final Offset a;
  final Offset b;
  final double ancho;
  const _Tramo(this.a, this.b, this.ancho);
}

class _PintorBrazo extends CustomPainter {
  final TipoVista vista;
  final double flexion;
  final double desviacion;
  final double antebrazo;
  final Color colorEstado;

  _PintorBrazo({
    required this.vista,
    required this.flexion,
    required this.desviacion,
    required this.antebrazo,
    required this.colorEstado,
  });

  static double _rad(double grados) => grados * pi / 180;

  // Gira un punto alrededor del origen (ángulo en radianes, horario +)
  static Offset _girar(Offset p, double a) =>
      Offset(p.dx * cos(a) - p.dy * sin(a), p.dx * sin(a) + p.dy * cos(a));

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 340; // escala
    final fondo = Paint()..color = Colores.azulSuave.withValues(alpha: 0.45);
    canvas.drawRect(Offset.zero & size, fondo);

    if (vista == TipoVista.lateral) {
      _pintarLateral(canvas, size, k);
    } else {
      _pintarSuperior(canvas, size, k);
    }
  }

  // Vista de lado: antebrazo sube/baja (IMU 1), mano dobla (flexión)
  void _pintarLateral(Canvas canvas, Size size, double k) {
    final codo = Offset(size.width * 0.16, size.height * 0.62);
    final aBrazo = _rad(-antebrazo); // arriba = negativo en pantalla
    final aMano = aBrazo + _rad(flexion); // flexión = mano hacia abajo
    final largo = 150 * k;

    Offset brazo(Offset p) => codo + _girar(p, aBrazo);
    final muneca = brazo(Offset(largo, 0));
    Offset mano(Offset p) => muneca + _girar(p, aMano);

    // Línea de referencia: mano recta
    _lineaPunteada(canvas, muneca, muneca + _girar(Offset(110 * k, 0), aBrazo), k);

    final tramos = [
      _Tramo(codo, codo + Offset(-25 * k, -150 * k), 40 * k), // brazo
      _Tramo(codo, muneca, 34 * k), // antebrazo
      _Tramo(mano(Offset.zero), mano(Offset(50 * k, 0)), 36 * k), // palma
      _Tramo(mano(Offset(46 * k, 2 * k)), mano(Offset(100 * k, 2 * k)), 22 * k), // dedos
    ];
    _pintarCuerpo(canvas, tramos, k);

    // Brazalete sobre el antebrazo
    final centroBrazalete = brazo(Offset(largo * 0.72, 0));
    _pintarBrazalete(canvas, centroBrazalete, aBrazo, 30 * k, 44 * k, k);

    // Marcas de las IMU
    final imu1 = brazo(Offset(largo * 0.72, -32 * k));
    final imu2 = mano(Offset(26 * k, -18 * k));
    _pintarImu(canvas, imu1, 'IMU 1', k);
    _pintarImu(canvas, imu2, 'IMU 2', k);
  }

  // Vista desde arriba: mano gira hacia pulgar o meñique (desviación)
  void _pintarSuperior(Canvas canvas, Size size, double k) {
    final codo = Offset(size.width * 0.12, size.height * 0.52);
    final largo = 150 * k;
    final muneca = codo + Offset(largo, 0);
    final aMano = _rad(-desviacion); // pulgar = hacia arriba en pantalla
    Offset mano(Offset p) => muneca + _girar(p, aMano);

    _lineaPunteada(canvas, muneca, muneca + Offset(115 * k, 0), k);

    final tramos = <_Tramo>[
      _Tramo(codo + Offset(-60 * k, 0), muneca, 40 * k), // antebrazo
      _Tramo(mano(Offset.zero), mano(Offset(44 * k, 0)), 44 * k), // palma
      _Tramo(mano(Offset(8 * k, -20 * k)), mano(Offset(32 * k, -40 * k)), 12 * k), // pulgar
    ];
    // Dedos: índice (arriba) a meñique (abajo)
    const filas = [-15.0, -5.0, 5.0, 15.0];
    const largos = [50.0, 56.0, 52.0, 42.0];
    for (var i = 0; i < 4; i++) {
      tramos.add(_Tramo(
        mano(Offset(40 * k, filas[i] * k)),
        mano(Offset((40 + largos[i]) * k, filas[i] * k)),
        10 * k,
      ));
    }
    _pintarCuerpo(canvas, tramos, k);

    _pintarBrazalete(canvas, codo + Offset(largo * 0.72, 0), 0, 30 * k, 50 * k, k);

    // Guías de dirección
    _texto(canvas, 'Pulgar', mano(Offset(70 * k, -48 * k)), k, Colores.textoSuave);
    _texto(canvas, 'Meñique', mano(Offset(70 * k, 34 * k)), k, Colores.textoSuave);
  }

  // Primero contornos y luego relleno, para que las uniones se vean limpias
  void _pintarCuerpo(Canvas canvas, List<_Tramo> tramos, double k) {
    final contorno = Paint()
      ..color = Colores.contornoPiel
      ..strokeCap = StrokeCap.round;
    final relleno = Paint()
      ..color = Colores.piel
      ..strokeCap = StrokeCap.round;
    for (final t in tramos) {
      canvas.drawLine(t.a, t.b, contorno..strokeWidth = t.ancho + 4 * k);
    }
    for (final t in tramos) {
      canvas.drawLine(t.a, t.b, relleno..strokeWidth = t.ancho);
    }
  }

  // Brazalete con la pantalla del color del semáforo
  void _pintarBrazalete(Canvas canvas, Offset centro, double angulo,
      double ancho, double alto, double k) {
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(angulo);
    final banda = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: ancho, height: alto),
      Radius.circular(8 * k),
    );
    canvas.drawRRect(banda, Paint()..color = Colores.brazalete);
    final pantalla = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: ancho * 0.6, height: ancho * 0.6),
      Radius.circular(4 * k),
    );
    canvas.drawRRect(pantalla, Paint()..color = colorEstado);
    canvas.restore();
  }

  // Punto azul con su etiqueta
  void _pintarImu(Canvas canvas, Offset p, String etiqueta, double k) {
    canvas.drawCircle(p, 7 * k, Paint()..color = Colores.blanco);
    canvas.drawCircle(p, 5 * k, Paint()..color = Colores.primario);
    _texto(canvas, etiqueta, p + Offset(0, -16 * k), k, Colores.primarioOscuro);
  }

  void _lineaPunteada(Canvas canvas, Offset a, Offset b, double k) {
    final pincel = Paint()
      ..color = Colores.textoSuave.withValues(alpha: 0.5)
      ..strokeWidth = 1.5 * k;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (double d = 0; d < total; d += 10 * k) {
      final fin = min(d + 5 * k, total);
      canvas.drawLine(a + dir * d, a + dir * fin, pincel);
    }
  }

  void _texto(Canvas canvas, String texto, Offset centro, double k, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: color, fontSize: 11 * k, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorBrazo old) =>
      old.flexion != flexion ||
      old.desviacion != desviacion ||
      old.antebrazo != antebrazo ||
      old.colorEstado != colorEstado;
}
