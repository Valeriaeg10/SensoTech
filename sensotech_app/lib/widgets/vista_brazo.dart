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
        aspectRatio: 1.55,
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

  // Gira un punto alrededor del origen (radianes, horario +)
  static Offset _girar(Offset p, double a) =>
      Offset(p.dx * cos(a) - p.dy * sin(a), p.dx * sin(a) + p.dy * cos(a));

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 340; // escala
    canvas.drawRect(Offset.zero & size, Paint()..color = Colores.azulSuave.withValues(alpha: 0.45));
    if (vista == TipoVista.lateral) {
      _pintarLateral(canvas, size, k);
    } else {
      _pintarSuperior(canvas, size, k);
    }
  }

  // De lado: antebrazo sube/baja (IMU 1), mano dobla (flexión)
  void _pintarLateral(Canvas canvas, Size size, double k) {
    final codo = Offset(size.width * 0.10, size.height * 0.52);
    final aBrazo = _rad(-antebrazo); // arriba = negativo en pantalla
    final aMano = aBrazo + _rad(flexion); // flexión = mano hacia abajo
    final largo = 130 * k;

    Offset brazo(Offset p) => codo + _girar(p, aBrazo);
    final muneca = brazo(Offset(largo, 0));
    Offset mano(Offset p) => muneca + _girar(p, aMano);

    _lineaPunteada(canvas, muneca, muneca + _girar(Offset(112 * k, 0), aBrazo), k);

    _pintarCuerpo(canvas, [
      _Tramo(codo + Offset(-40 * k, 0), muneca, 34 * k), // antebrazo
      _Tramo(mano(Offset(8 * k, 6 * k)), mano(Offset(40 * k, 16 * k)), 12 * k), // pulgar
      _Tramo(mano(Offset.zero), mano(Offset(46 * k, 0)), 34 * k), // palma
      _Tramo(mano(Offset(44 * k, 7 * k)), mano(Offset(92 * k, 7 * k)), 12 * k), // dedo de atrás
      _Tramo(mano(Offset(44 * k, -5 * k)), mano(Offset(98 * k, -5 * k)), 14 * k), // dedo del frente
    ], k);

    _pintarBrazalete(canvas, brazo(Offset(largo * 0.70, 0)), aBrazo, 28 * k, 44 * k, k);
    _pintarArco(canvas, muneca, aBrazo, aMano, flexion, k);

    _pintarImu(canvas, brazo(Offset(largo * 0.70, -30 * k)), '1', k);
    _pintarImu(canvas, mano(Offset(24 * k, -21 * k)), '2', k);
  }

  // Desde arriba: mano gira hacia pulgar o meñique (desviación)
  void _pintarSuperior(Canvas canvas, Size size, double k) {
    final codo = Offset(size.width * 0.10, size.height * 0.54);
    final largo = 130 * k;
    final muneca = codo + Offset(largo, 0);
    final aMano = _rad(-desviacion); // pulgar = arriba en pantalla
    Offset mano(Offset p) => muneca + _girar(p, aMano);

    _lineaPunteada(canvas, muneca, muneca + Offset(112 * k, 0), k);

    final tramos = <_Tramo>[
      _Tramo(codo + Offset(-40 * k, 0), muneca, 40 * k), // antebrazo
      _Tramo(mano(Offset.zero), mano(Offset(44 * k, 0)), 44 * k), // palma
      _Tramo(mano(Offset(8 * k, -20 * k)), mano(Offset(30 * k, -40 * k)), 12 * k), // pulgar
    ];
    // Dedos: índice (arriba) a meñique (abajo)
    const filas = [-15.0, -5.0, 5.0, 15.0];
    const largos = [48.0, 54.0, 50.0, 40.0];
    for (var i = 0; i < 4; i++) {
      tramos.add(_Tramo(
        mano(Offset(40 * k, filas[i] * k)),
        mano(Offset((40 + largos[i]) * k, filas[i] * k)),
        10 * k,
      ));
    }
    _pintarCuerpo(canvas, tramos, k);

    _pintarBrazalete(canvas, codo + Offset(largo * 0.70, 0), 0, 28 * k, 50 * k, k);
    _pintarArco(canvas, muneca, 0, aMano, desviacion, k);
    _pintarImu(canvas, mano(Offset(22 * k, 6 * k)), '2', k);

    _texto(canvas, 'Pulgar', Offset(muneca.dx + 60 * k, size.height * 0.10), k, Colores.textoSuave);
    _texto(canvas, 'Meñique', Offset(muneca.dx + 60 * k, size.height * 0.92), k, Colores.textoSuave);
  }

  // Primero contornos y luego relleno, para uniones limpias
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: ancho, height: alto), Radius.circular(8 * k)),
      Paint()..color = Colores.brazalete,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: ancho * 0.6, height: ancho * 0.6),
          Radius.circular(4 * k)),
      Paint()..color = colorEstado,
    );
    canvas.restore();
  }

  // Arco entre la mano recta y la mano real, con el valor
  void _pintarArco(Canvas canvas, Offset centro, double desde, double hasta, double grados, double k) {
    final radio = 112 * k;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      desde,
      hasta - desde,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * k
        ..strokeCap = StrokeCap.round
        ..color = Colores.primario,
    );
    final medio = desde + (hasta - desde) / 2;
    final pos = centro + _girar(Offset(radio + 20 * k, 0), medio);
    _texto(canvas, '${grados.abs().toStringAsFixed(0)}°', pos, k, Colores.primarioOscuro, grande: true);
  }

  // Punto numerado de la IMU
  void _pintarImu(Canvas canvas, Offset p, String numero, double k) {
    canvas.drawCircle(p, 9 * k, Paint()..color = Colores.blanco);
    canvas.drawCircle(p, 7.5 * k, Paint()..color = Colores.primario);
    _texto(canvas, numero, p, k * 0.85, Colores.blanco);
  }

  void _lineaPunteada(Canvas canvas, Offset a, Offset b, double k) {
    final pincel = Paint()
      ..color = Colores.textoSuave.withValues(alpha: 0.5)
      ..strokeWidth = 1.5 * k;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (double d = 0; d < total; d += 10 * k) {
      canvas.drawLine(a + dir * d, a + dir * min(d + 5 * k, total), pincel);
    }
  }

  void _texto(Canvas canvas, String texto, Offset centro, double k, Color color, {bool grande = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: color,
          fontSize: (grande ? 14 : 11) * k,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorBrazo old) =>
      old.vista != vista ||
      old.flexion != flexion ||
      old.desviacion != desviacion ||
      old.antebrazo != antebrazo ||
      old.colorEstado != colorEstado;
}
