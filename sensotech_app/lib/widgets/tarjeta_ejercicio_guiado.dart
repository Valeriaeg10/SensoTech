import 'dart:math';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ejercicios.dart';
import '../tema/colores.dart';
import 'animacion_ejercicio.dart';
import 'cache_brazo.dart';
import 'vista_brazo.dart';

// Ejercicio guiado (pausa activa o rehabilitación): demostración, medidor, repeticiones,
// tiempo sosteniendo, descanso y alerta de seguridad.
class TarjetaEjercicioGuiado extends StatefulWidget {
  final EjercicioEnCurso ejercicio;
  final LecturaEnVivo lectura;
  final bool izquierda;
  final String etiqueta; // 'Pausa activa', 'Rehabilitación'…
  final String? posicion; // 'Ejercicio 2 de 3'

  const TarjetaEjercicioGuiado({
    super.key,
    required this.ejercicio,
    required this.lectura,
    required this.izquierda,
    required this.etiqueta,
    this.posicion,
  });

  // Ejercicio del catálogo (null en las evaluaciones)
  static DefEjercicio? defDe(EjercicioEnCurso e) {
    if (e.esEvaluacion || e.codigo >= IdEjercicio.values.length) return null;
    return catalogo[IdEjercicio.values[e.codigo]];
  }

  static String nombreDe(EjercicioEnCurso e) =>
      e.esEvaluacion ? 'Evaluación: ${e.movimientoEvaluado.texto.toLowerCase()}' : (defDe(e)?.nombre ?? 'Ejercicio');

  @override
  State<TarjetaEjercicioGuiado> createState() => _TarjetaEjercicioGuiadoState();
}

class _TarjetaEjercicioGuiadoState extends State<TarjetaEjercicioGuiado> {
  DateTime _ultimoRiesgo = DateTime(2000);
  int _codigo = -1;
  double _maximo = 0; // evaluación: lo máximo que ha llegado en este movimiento
  String _clave = ''; // ejercicio y serie actuales
  bool _enDescanso = false;
  DateTime _inicio = DateTime.now(); // cuándo empezó el ejercicio (para la demostración)

  static const _segundosDemo = 6;

  @override
  void initState() {
    super.initState();
    CacheBrazo.cargar().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.ejercicio;
    final l = widget.lectura;
    final def = TarjetaEjercicioGuiado.defDe(e);
    final ahora = DateTime.now();

    if (e.codigo != _codigo) {
      _codigo = e.codigo;
      _maximo = 0;
    }
    // Reinicia el tiempo de la demostración al empezar un ejercicio o al terminar un descanso
    final clave = '${e.codigo}-${e.serie}';
    if (clave != _clave || (_enDescanso && e.descanso == 0)) {
      _clave = clave;
      _inicio = ahora;
    }
    _enDescanso = e.descanso > 0;
    // Primero la demostración (solo en la primera serie), luego la muñeca en vivo
    final verDemo = e.descanso == 0 &&
        e.serie == 1 &&
        e.repeticion == 0 &&
        ahora.difference(_inicio).inSeconds < _segundosDemo;
    // La alerta se queda visible 2,5 s para que alcance a leerse
    if (e.zona == ZonaEjercicio.riesgo) _ultimoRiesgo = ahora;
    final alerta = ahora.difference(_ultimoRiesgo).inMilliseconds < 2500;

    final config = _Medidor.de(e, def, l);
    if (e.esEvaluacion && e.descanso == 0) _maximo = max(_maximo, config.valor);

    final demo = def?.demo ?? AnimacionEjercicio.demoDe(e.movimientoEvaluado);
    final metaDemo = e.objetivo.abs() > 0 && demo != Demo.puno ? e.objetivo.abs() : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5AB0FF), Colores.primarioOscuro],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(e.esEvaluacion ? Icons.straighten_rounded : Icons.self_improvement_rounded,
                  color: Colores.blanco),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.etiqueta,
                    style: const TextStyle(color: Colores.blanco, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (widget.posicion != null)
                Text(widget.posicion!, style: const TextStyle(color: Colores.blanco, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colores.blanco, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TarjetaEjercicioGuiado.nombreDe(e),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 4),
                Text(
                  def?.instruccion ??
                      'Lleva la muñeca al máximo de ${e.movimientoEvaluado.texto.toLowerCase()} '
                          'que logres sin dolor y sostén la posición.',
                  style: const TextStyle(color: Colores.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (e.descanso > 0)
                  AnimacionEjercicio(demo: demo, izquierda: widget.izquierda, pausada: true, ampliable: false)
                else if (verDemo) ...[
                  _rotulo(Icons.play_circle_outline_rounded, 'Mira cómo se hace',
                      'En ${_segundosDemo - ahora.difference(_inicio).inSeconds} s empiezas tú'),
                  const SizedBox(height: 6),
                  AnimacionEjercicio(
                    demo: demo,
                    izquierda: widget.izquierda,
                    meta: metaDemo,
                    titulo: TarjetaEjercicioGuiado.nombreDe(e),
                    descripcion: def?.instruccion,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _rotulo(Icons.sensors_rounded, 'Tu muñeca en vivo', null)),
                      TextButton.icon(
                        onPressed: () => AnimacionEjercicio.abrir(
                          context,
                          demo,
                          izquierda: widget.izquierda,
                          meta: metaDemo,
                          titulo: TarjetaEjercicioGuiado.nombreDe(e),
                          descripcion: def?.instruccion,
                        ),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                        label: const Text('Ver demostración'),
                      ),
                    ],
                  ),
                  _enVivo(e, l, demo),
                ],
                const SizedBox(height: 14),
                if (e.descanso > 0)
                  _descanso(e)
                else ...[
                  _lineaValores(e, def, config),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: CustomPaint(painter: _PintorMedidor(config, e.zona)),
                  ),
                  const SizedBox(height: 12),
                  if (alerta) _alerta(def) else _estado(e, def),
                  const SizedBox(height: 12),
                  _repeticiones(e),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rotulo(IconData i, String t, String? sub) => Row(
        children: [
          Icon(i, size: 18, color: Colores.primario),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Colores.primarioOscuro)),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Text(sub, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          ],
        ],
      );

  // Brazo 3D con el movimiento real; la pantalla del brazalete toma el color de la zona
  Widget _enVivo(EjercicioEnCurso e, LecturaEnVivo l, Demo demo) {
    if (!CacheBrazo.listo) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    final color = switch (e.zona) {
      ZonaEjercicio.riesgo => Colores.rojo,
      ZonaEjercicio.enMeta => Colores.verde,
      ZonaEjercicio.normal => Colores.primario,
    };
    return VistaBrazo(
      vista: demo == Demo.pendulo ? TipoVista.superior : TipoVista.lateral,
      lectura: l,
      colorEstado: color,
      izquierda: widget.izquierda,
    );
  }

  // Ángulo actual, meta y tiempo sosteniendo
  Widget _lineaValores(EjercicioEnCurso e, DefEjercicio? def, _Medidor m) {
    final sostiene = e.esEvaluacion || (def != null && def.sostener > 0);
    final etiquetaMeta = e.esEvaluacion
        ? (e.objetivo.abs() > 0 ? 'Anterior ${e.objetivo.abs().round()}°' : 'Primera medición')
        : (def?.id == IdEjercicio.p3Dedos ? 'Máximo ${def!.riesgo!.round()}°' : 'Meta ${e.objetivo.abs().round()}°');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${m.valor.abs().round()}°',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              e.esEvaluacion ? '$etiquetaMeta · Máximo hoy ${_maximo.round()}°' : etiquetaMeta,
              style: const TextStyle(fontSize: 14, color: Colores.textoSuave, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (sostiene) _reloj(e, def),
      ],
    );
  }

  // Cuenta regresiva de sostener (o duración de la evaluación)
  Widget _reloj(EjercicioEnCurso e, DefEjercicio? def) {
    final total = e.esEvaluacion ? 10 : max(def!.sostener, 1);
    final activo = e.zona == ZonaEjercicio.enMeta || e.esEvaluacion;
    final avance = (1 - e.sostener / total).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: e.esEvaluacion ? null : avance,
              strokeWidth: 5,
              backgroundColor: Colores.azulSuave,
              color: activo ? Colores.verde : Colores.primario,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${e.sostener}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1)),
              const Text('s', style: TextStyle(fontSize: 10, color: Colores.textoSuave)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estado(EjercicioEnCurso e, DefEjercicio? def) {
    final (String texto, Color color, IconData icono) = switch (e.zona) {
      ZonaEjercicio.enMeta => (
          def?.id == IdEjercicio.p3Dedos
              ? 'Muñeca en posición neutra'
              : (def != null && def.sostener > 0 ? 'En la meta: sostén la posición' : 'En la meta'),
          Colores.verde,
          Icons.check_circle_rounded,
        ),
      _ => (
          e.esEvaluacion ? 'Muévete despacio, sin dolor' : 'Avanza con control hacia la meta',
          Colores.primario,
          Icons.trending_up_rounded,
        ),
    };
    return Row(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
      ],
    );
  }

  Widget _alerta(DefEjercicio? def) {
    final consejo = switch (def?.id) {
      IdEjercicio.p1Bombeo => 'Disminuye la amplitud del movimiento.',
      IdEjercicio.p2Isometrico => 'Reduce la extensión hasta la zona meta.',
      IdEjercicio.p3Dedos => 'Regresa la muñeca a posición neutra.',
      _ => 'Regresa a la zona segura.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colores.rojo.withValues(alpha: 0.1),
        border: Border.all(color: Colores.rojo),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colores.rojo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Has alcanzado el límite de seguridad',
                    style: TextStyle(color: Colores.rojo, fontWeight: FontWeight.w800)),
                Text(consejo, style: const TextStyle(color: Colores.rojo, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _repeticiones(EjercicioEnCurso e) {
    final total = e.repeticionesTotal;
    final serie = e.seriesTotal > 1 ? 'Serie ${e.serie} de ${e.seriesTotal} · ' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          e.esEvaluacion ? 'Medición de rango articular' : '${serie}Repetición ${min(e.repeticion + 1, total)} de $total',
          style: const TextStyle(color: Colores.textoSuave, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (!e.esEvaluacion && total > 1) ...[
          const SizedBox(height: 8),
          if (total <= 12)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < e.repeticion ? Colores.verde : Colores.azulSuave,
                    ),
                    child: i < e.repeticion ? const Icon(Icons.check_rounded, size: 14, color: Colores.blanco) : null,
                  ),
              ],
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: e.repeticion / total,
                minHeight: 10,
                backgroundColor: Colores.azulSuave,
                color: Colores.verde,
              ),
            ),
        ],
      ],
    );
  }

  Widget _descanso(EjercicioEnCurso e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(color: Colores.azulSuave, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          const Icon(Icons.hourglass_bottom_rounded, color: Colores.primario, size: 30),
          const SizedBox(height: 6),
          const Text('Descanso', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${e.descanso} s',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colores.primarioOscuro)),
          Text(
            e.esEvaluacion
                ? 'Luego se mide tu rango articular'
                : 'Siguiente: serie ${e.serie} de ${e.seriesTotal}, mira la demostración',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Qué muestra el medidor horizontal
class _Medidor {
  final double valor; // ángulo actual (con signo si es de dos lados)
  final bool dosLados;
  final double escala; // grados de cada extremo
  final double? metaDesde;
  final double? metaHasta;
  final double? riesgo;
  final bool neutro; // zona segura alrededor de 0
  final String izquierdo;
  final String derecho;

  const _Medidor({
    required this.valor,
    required this.dosLados,
    required this.escala,
    this.metaDesde,
    this.metaHasta,
    this.riesgo,
    this.neutro = false,
    this.izquierdo = '',
    this.derecho = '',
  });

  factory _Medidor.de(EjercicioEnCurso e, DefEjercicio? def, LecturaEnVivo l) {
    final meta = e.objetivo.abs();
    if (e.esEvaluacion) {
      final mov = e.movimientoEvaluado;
      final v = mov.desde(l);
      return _Medidor(
        valor: v,
        dosLados: false,
        escala: max(rangoMax(mov), meta + 10),
        metaDesde: meta > 0 ? meta : null,
        metaHasta: meta > 0 ? meta + 0.8 : null,
        derecho: mov.corto,
      );
    }
    final d = def!;
    switch (d.id) {
      case IdEjercicio.r3Pendulo:
        return _Medidor(
          valor: l.desviacion,
          dosLados: true,
          escala: (d.riesgo ?? 20) + 10,
          metaDesde: meta - 3,
          metaHasta: min(meta + 3, d.riesgo ?? 99),
          riesgo: d.riesgo,
          izquierdo: 'Cubital',
          derecho: 'Radial',
        );
      case IdEjercicio.p1Bombeo:
        return _Medidor(
          valor: l.flexion,
          dosLados: true,
          escala: (d.riesgo ?? 50) + 10,
          metaDesde: meta - 3,
          metaHasta: meta + 3,
          riesgo: d.riesgo,
          izquierdo: 'Extensión',
          derecho: 'Flexión',
        );
      case IdEjercicio.p3Dedos:
        return _Medidor(
          valor: l.flexion,
          dosLados: true,
          escala: 30,
          riesgo: d.riesgo,
          neutro: true,
          izquierdo: 'Extensión',
          derecho: 'Flexión',
        );
      case IdEjercicio.p2Isometrico:
        return _Medidor(
          valor: d.movimientos.first.desde(l),
          dosLados: false,
          escala: 60,
          metaDesde: meta,
          metaHasta: d.riesgo ?? meta + 5,
          riesgo: d.riesgo,
          derecho: d.movimientos.first.corto,
        );
      default:
        return _Medidor(
          valor: d.movimientos.first.desde(l),
          dosLados: false,
          escala: max(60, meta + 15),
          metaDesde: meta - 3,
          metaHasta: meta + 3,
          riesgo: d.riesgo,
          derecho: d.movimientos.first.corto,
        );
    }
  }

  static double rangoMax(TipoEjercicio t) => switch (t) {
        TipoEjercicio.flexion => 80,
        TipoEjercicio.extension => 70,
        TipoEjercicio.radial => 30,
        TipoEjercicio.cubital => 40,
      };
}

class _PintorMedidor extends CustomPainter {
  final _Medidor m;
  final ZonaEjercicio zona;

  _PintorMedidor(this.m, this.zona);

  @override
  void paint(Canvas canvas, Size size) {
    const alto = 14.0;
    final y = 10.0;
    final ancho = size.width;
    double x(double grados) {
      final g = grados.clamp(m.dosLados ? -m.escala : 0.0, m.escala);
      return m.dosLados ? ancho / 2 + g / m.escala * ancho / 2 : g / m.escala * ancho;
    }

    final r = RRect.fromLTRBR(0, y, ancho, y + alto, const Radius.circular(7));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(r.outerRect, Paint()..color = Colores.azulSuave);

    final verde = Paint()..color = Colores.verde.withValues(alpha: 0.45);
    final rojo = Paint()..color = Colores.rojo.withValues(alpha: 0.35);
    void banda(double a, double b, Paint p) => canvas.drawRect(Rect.fromLTRB(x(a), y, x(b), y + alto), p);

    if (m.neutro && m.riesgo != null) {
      banda(-m.riesgo!, m.riesgo!, verde);
    } else if (m.metaDesde != null && m.metaHasta != null) {
      banda(m.metaDesde!, m.metaHasta!, verde);
      if (m.dosLados) banda(-m.metaHasta!, -m.metaDesde!, verde);
    }
    if (m.riesgo != null) {
      banda(m.riesgo!, m.escala, rojo);
      if (m.dosLados) banda(-m.escala, -m.riesgo!, rojo);
    }
    canvas.restore();

    // Centro (posición neutra)
    final cx = m.dosLados ? ancho / 2 : 0.0;
    canvas.drawLine(Offset(cx, y - 4), Offset(cx, y + alto + 4), Paint()
      ..color = Colores.textoSuave
      ..strokeWidth = 1.5);

    // Aguja con el ángulo actual
    final color = switch (zona) {
      ZonaEjercicio.riesgo => Colores.rojo,
      ZonaEjercicio.enMeta => Colores.verde,
      ZonaEjercicio.normal => Colores.primario,
    };
    final p = Offset(x(m.valor), y + alto / 2);
    canvas.drawCircle(p, 11, Paint()..color = Colores.blanco);
    canvas.drawCircle(p, 8, Paint()..color = color);

    // Rótulos de los extremos
    void texto(String t, Offset o, TextAlign a) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: const TextStyle(color: Colores.textoSuave, fontSize: 11)),
        textDirection: TextDirection.ltr,
        textAlign: a,
      )..layout();
      final dx = a == TextAlign.right ? o.dx - tp.width : (a == TextAlign.center ? o.dx - tp.width / 2 : o.dx);
      tp.paint(canvas, Offset(dx, o.dy));
    }

    final abajo = y + alto + 6;
    if (m.izquierdo.isNotEmpty) texto(m.izquierdo, Offset(0, abajo), TextAlign.left);
    if (m.derecho.isNotEmpty) texto(m.derecho, Offset(ancho, abajo), TextAlign.right);
    texto('0°', Offset(cx, abajo), m.dosLados ? TextAlign.center : TextAlign.left);
  }

  @override
  bool shouldRepaint(covariant _PintorMedidor old) => true;
}
