import 'dart:math';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../tema/colores.dart';

// Qué vista dibujar
enum TipoVista { lateral, superior }

// Dibujo del antebrazo y la mano con las dos IMU y la estela del movimiento
class VistaBrazo extends StatelessWidget {
  final TipoVista vista;
  final LecturaEnVivo lectura;
  final List<LecturaEnVivo> estela; // lecturas anteriores (la más vieja primero)
  final Color colorEstado;

  const VistaBrazo({
    super.key,
    required this.vista,
    required this.lectura,
    required this.estela,
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
            lectura: lectura,
            estela: estela,
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

// Posición del brazo para unos ángulos dados
class _Pose {
  final Offset codo;
  final Offset muneca;
  final Offset pivote; // centro del carpo: ahí gira la mano
  final double aBrazo;
  final double aMano;
  final double k;

  _Pose(this.codo, this.muneca, this.pivote, this.aBrazo, this.aMano, this.k);

  // Punto del antebrazo (x a lo largo, y hacia el dorso)
  Offset brazo(Offset p) => codo + _girar(p, aBrazo);

  // Punto de la mano medido desde la muñeca; gira alrededor del carpo
  Offset mano(Offset p) => pivote + _girar(p - Offset(12 * k, 0), aMano);

  static Offset _girar(Offset p, double a) =>
      Offset(p.dx * cos(a) - p.dy * sin(a), p.dx * sin(a) + p.dy * cos(a));
}

class _PintorBrazo extends CustomPainter {
  final TipoVista vista;
  final LecturaEnVivo lectura;
  final List<LecturaEnVivo> estela;
  final Color colorEstado;

  _PintorBrazo({
    required this.vista,
    required this.lectura,
    required this.estela,
    required this.colorEstado,
  });

  static double _rad(double grados) => grados * pi / 180;
  static const _largo = 130.0;

  // Geometría de la vista lateral
  _Pose _poseLateral(Size size, double k, LecturaEnVivo l) {
    final codo = Offset(size.width * 0.10, size.height * 0.52);
    final aBrazo = _rad(-l.antebrazo); // arriba = negativo en pantalla
    final aMano = aBrazo + _rad(l.flexion); // flexión = mano hacia abajo
    final muneca = codo + _Pose._girar(Offset(_largo * k, 0), aBrazo);
    final pivote = codo + _Pose._girar(Offset((_largo + 12) * k, 0), aBrazo);
    return _Pose(codo, muneca, pivote, aBrazo, aMano, k);
  }

  // Geometría de la vista superior (antebrazo fijo)
  _Pose _poseSuperior(Size size, double k, LecturaEnVivo l) {
    final codo = Offset(size.width * 0.10, size.height * 0.54);
    final muneca = codo + Offset(_largo * k, 0);
    return _Pose(codo, muneca, muneca + Offset(12 * k, 0), 0, _rad(-l.desviacion), k);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 340; // escala
    canvas.drawRect(Offset.zero & size, Paint()..color = Colores.azulSuave.withValues(alpha: 0.45));

    final lateral = vista == TipoVista.lateral;
    _Pose poseDe(LecturaEnVivo l) => lateral ? _poseLateral(size, k, l) : _poseSuperior(size, k, l);
    final p = poseDe(lectura);

    // Línea de mano recta
    _lineaPunteada(canvas, p.pivote, p.pivote + _Pose._girar(Offset(110 * k, 0), p.aBrazo), k);

    // Estela: camino de la punta del dedo medio
    final punta = lateral ? Offset(98 * k, -5 * k) : Offset(94 * k, -5 * k);
    _pintarEstela(canvas, [for (final l in estela) poseDe(l).mano(punta)], k);

    if (lateral) {
      _pintarLateral(canvas, p, k);
    } else {
      _pintarSuperior(canvas, size, p, k);
    }
  }

  void _pintarLateral(Canvas canvas, _Pose p, double k) {
    _pintarCuerpo(canvas, [
      _Tramo(p.brazo(Offset(-40 * k, 0)), p.muneca, 34 * k), // antebrazo
      _Tramo(p.mano(Offset(8 * k, 6 * k)), p.mano(Offset(40 * k, 16 * k)), 12 * k), // pulgar
      _Tramo(p.mano(Offset.zero), p.mano(Offset(46 * k, 0)), 34 * k), // palma
      _Tramo(p.mano(Offset(44 * k, 7 * k)), p.mano(Offset(92 * k, 7 * k)), 12 * k), // dedo de atrás
      _Tramo(p.mano(Offset(44 * k, -5 * k)), p.mano(Offset(98 * k, -5 * k)), 14 * k), // dedo del frente
    ], k);

    _pintarBrazalete(canvas, p.brazo(Offset(_largo * 0.70 * k, 0)), p.aBrazo, 28 * k, 44 * k, k);
    _pintarArco(canvas, p.pivote, p.aBrazo, p.aMano, lectura.flexion, k);
    _pintarImu(canvas, p.brazo(Offset(_largo * 0.70 * k, -30 * k)), '1', k);
    _pintarImu(canvas, p.mano(Offset(24 * k, -21 * k)), '2', k);
  }

  void _pintarSuperior(Canvas canvas, Size size, _Pose p, double k) {
    final tramos = <_Tramo>[
      _Tramo(p.codo + Offset(-40 * k, 0), p.muneca, 40 * k), // antebrazo
      _Tramo(p.mano(Offset.zero), p.mano(Offset(44 * k, 0)), 44 * k), // palma
      _Tramo(p.mano(Offset(8 * k, -20 * k)), p.mano(Offset(30 * k, -40 * k)), 12 * k), // pulgar
    ];
    // Dedos: índice (arriba) a meñique (abajo)
    const filas = [-15.0, -5.0, 5.0, 15.0];
    const largos = [48.0, 54.0, 50.0, 40.0];
    for (var i = 0; i < 4; i++) {
      tramos.add(_Tramo(
        p.mano(Offset(40 * k, filas[i] * k)),
        p.mano(Offset((40 + largos[i]) * k, filas[i] * k)),
        10 * k,
      ));
    }
    _pintarCuerpo(canvas, tramos, k);

    _pintarBrazalete(canvas, p.codo + Offset(_largo * 0.70 * k, 0), 0, 28 * k, 50 * k, k);
    _pintarArco(canvas, p.pivote, 0, p.aMano, lectura.desviacion, k);
    _pintarImu(canvas, p.mano(Offset(22 * k, 6 * k)), '2', k);

    _texto(canvas, 'Pulgar', Offset(p.muneca.dx + 60 * k, size.height * 0.08), k, Colores.textoSuave);
    _texto(canvas, 'Meñique', Offset(p.muneca.dx + 60 * k, size.height * 0.93), k, Colores.textoSuave);
  }

  // Línea que se desvanece hacia atrás en el tiempo
  void _pintarEstela(Canvas canvas, List<Offset> puntos, double k) {
    for (var i = 1; i < puntos.length; i++) {
      final opacidad = i / puntos.length;
      canvas.drawLine(
        puntos[i - 1],
        puntos[i],
        Paint()
          ..color = Colores.primario.withValues(alpha: 0.6 * opacidad)
          ..strokeWidth = 3 * k
          ..strokeCap = StrokeCap.round,
      );
    }
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
    final radio = 104 * k;
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
    final pos = centro + _Pose._girar(Offset(radio + 20 * k, 0), medio);
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
        style: TextStyle(color: color, fontSize: (grande ? 14 : 11) * k, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PintorBrazo old) => true; // llega una lectura nueva cada 100 ms
}
