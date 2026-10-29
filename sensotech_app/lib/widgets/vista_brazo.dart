import 'dart:math';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../tema/colores.dart';
import 'cache_brazo.dart';
import 'cuadros_brazo.dart';

// Qué vista dibujar
enum TipoVista { lateral, superior }

// Brazo 3D: muestra la imagen más cercana al ángulo y encima el arco con el valor exacto
class VistaBrazo extends StatelessWidget {
  final TipoVista vista;
  final LecturaEnVivo lectura;
  final Color colorEstado;
  final bool izquierda; // mano izquierda = imagen en espejo

  const VistaBrazo({
    super.key,
    required this.vista,
    required this.lectura,
    required this.colorEstado,
    this.izquierda = false,
  });

  // Ángulo de la imagen: múltiplo de 5 dentro del rango disponible
  static int anguloImagen(TipoVista v, double grados) {
    final lateral = v == TipoVista.lateral;
    final minimo = lateral ? CuadrosBrazo.latMin : CuadrosBrazo.supMin;
    final maximo = lateral ? CuadrosBrazo.latMax : CuadrosBrazo.supMax;
    final a = (grados / CuadrosBrazo.paso).round() * CuadrosBrazo.paso;
    return a.clamp(minimo, maximo);
  }

  static String archivo(TipoVista v, int a) => CacheBrazo.archivo(v == TipoVista.lateral, a);

  @override
  Widget build(BuildContext context) {
    final lateral = vista == TipoVista.lateral;
    final grados = lateral ? lectura.flexion : lectura.desviacion;
    final a = anguloImagen(vista, grados);
    final muneca = lateral ? CuadrosBrazo.munecaLat : CuadrosBrazo.munecaSup;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: CuadrosBrazo.ancho / CuadrosBrazo.alto,
        child: LayoutBuilder(builder: (_, c) {
          final k = c.maxWidth / CuadrosBrazo.ancho;
          // Antebrazo (IMU 1): la imagen se inclina alrededor de la muñeca, que queda fija
          final munecaX = izquierda ? CuadrosBrazo.ancho - muneca.dx : muneca.dx;
          final origen = Offset(munecaX * k - c.maxWidth / 2, muneca.dy * k - c.maxHeight / 2);
          final giro = lateral ? (izquierda ? 1 : -1) * lectura.antebrazo * pi / 180 : 0.0;

          return Container(
            color: Colores.azulSuave.withValues(alpha: 0.55),
            child: Transform.rotate(
              angle: giro,
              origin: origen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen ya cargada en memoria: cambia al instante
                  Transform.flip(
                    flipX: izquierda,
                    child: RawImage(image: CacheBrazo.imagen(archivo(vista, a)), fit: BoxFit.fill),
                  ),
                  CustomPaint(
                    painter: _Superposicion(
                      vista: vista,
                      grados: grados,
                      anguloImagen: a,
                      colorEstado: colorEstado,
                      izquierda: izquierda,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Encima de la imagen: pantalla del brazalete, línea recta, arco y números de las IMU
class _Superposicion extends CustomPainter {
  final TipoVista vista;
  final double grados;
  final int anguloImagen;
  final Color colorEstado;
  final bool izquierda;

  _Superposicion({
    required this.vista,
    required this.grados,
    required this.anguloImagen,
    required this.colorEstado,
    required this.izquierda,
  });

  bool get _lateral => vista == TipoVista.lateral;

  // Refleja un punto si es la mano izquierda
  Offset _p(Offset o) => izquierda ? Offset(CuadrosBrazo.ancho - o.dx, o.dy) : o;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / CuadrosBrazo.ancho);
    final muneca = _p(_lateral ? CuadrosBrazo.munecaLat : CuadrosBrazo.munecaSup);
    final dir = izquierda ? -1.0 : 1.0;

    // Color del semáforo en la pantalla del brazalete (vista desde arriba)
    if (!_lateral) {
      final r = CuadrosBrazo.pantallaSup;
      final rect = izquierda
          ? Rect.fromLTRB(CuadrosBrazo.ancho - r.right, r.top, CuadrosBrazo.ancho - r.left, r.bottom)
          : r;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(5)),
        Paint()..color = colorEstado,
      );
    }

    // Línea de mano recta
    final linea = Paint()
      ..color = Colores.textoSuave.withValues(alpha: 0.7)
      ..strokeWidth = 2.5;
    for (double d = 0; d < 230; d += 14) {
      canvas.drawLine(muneca + Offset(dir * d, 0), muneca + Offset(dir * (d + 7), 0), linea);
    }

    // Arco con el ángulo real (no el de la imagen)
    final a = (_lateral ? grados : -grados) * pi / 180; // + = horario en pantalla
    const radio = 190.0;
    final inicio = izquierda ? pi : 0.0;
    final barrido = izquierda ? -a : a;
    if (a.abs() > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: muneca, radius: radio),
        inicio,
        barrido,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Colores.primario,
      );
    }
    final medio = inicio + barrido / 2;
    final pos = muneca + Offset(cos(medio), sin(medio)) * (radio + 42);
    final caja = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: 80, height: 38),
      const Radius.circular(19),
    );
    canvas.drawRRect(caja, Paint()..color = Colores.blanco);
    canvas.drawRRect(
      caja,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colores.primario,
    );
    _texto(canvas, '${grados.abs().toStringAsFixed(0)}°', pos, Colores.primarioOscuro, 24);

    // Números de las IMU
    final modulo = _p(_lateral ? CuadrosBrazo.moduloLat : CuadrosBrazo.moduloSup);
    final imu2 = _p((_lateral ? CuadrosBrazo.imu2Lat : CuadrosBrazo.imu2Sup)[anguloImagen] ?? Offset.zero);
    _numero(canvas, modulo + Offset(0, _lateral ? -44 : -58), '1');
    _numero(canvas, imu2 + const Offset(0, -30), '2');
  }

  void _numero(Canvas canvas, Offset p, String n) {
    canvas.drawCircle(p, 15, Paint()..color = Colores.blanco);
    canvas.drawCircle(p, 12.5, Paint()..color = Colores.primario);
    _texto(canvas, n, p, Colores.blanco, 16);
  }

  void _texto(Canvas canvas, String t, Offset centro, Color color, double tam) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: tam, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Superposicion old) =>
      old.grados != grados || old.colorEstado != colorEstado || old.izquierda != izquierda || old.vista != vista;
}
