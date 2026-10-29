import 'dart:math';
import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ejercicios.dart';
import '../tema/colores.dart';
import 'cache_brazo.dart';
import 'cuadros_brazo.dart';
import 'vista_brazo.dart';

// Demostración en movimiento (tipo video) de cómo se hace cada ejercicio, con el brazo 3D
class AnimacionEjercicio extends StatefulWidget {
  final Demo demo;
  final bool izquierda;
  final double? meta; // grados a mostrar; si es null usa el valor típico del ejercicio
  final bool pausada; // quieta en posición neutra (descanso)
  final bool ampliable; // al tocarla se abre en grande
  final String? titulo;
  final String? descripcion;

  const AnimacionEjercicio({
    super.key,
    required this.demo,
    this.izquierda = false,
    this.meta,
    this.pausada = false,
    this.ampliable = true,
    this.titulo,
    this.descripcion,
  });

  // Abre la demostración en grande con su explicación
  static Future<void> abrir(BuildContext context, Demo demo,
      {bool izquierda = false, double? meta, String? titulo, String? descripcion}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titulo != null)
                Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              AnimacionEjercicio(demo: demo, izquierda: izquierda, meta: meta, ampliable: false),
              if (descripcion != null) ...[
                const SizedBox(height: 10),
                Text(descripcion, style: const TextStyle(color: Colores.textoSuave)),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Demostración que corresponde a un movimiento (para las evaluaciones)
  static Demo demoDe(TipoEjercicio t) => switch (t) {
        TipoEjercicio.flexion => Demo.flexion,
        TipoEjercicio.extension => Demo.extension,
        TipoEjercicio.radial || TipoEjercicio.cubital => Demo.pendulo,
      };

  @override
  State<AnimacionEjercicio> createState() => _AnimacionEjercicioState();
}

class _AnimacionEjercicioState extends State<AnimacionEjercicio> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _duracion(widget.demo));

  static Duration _duracion(Demo d) => Duration(
        milliseconds: switch (d) {
          Demo.flexion || Demo.extension => 5000,
          Demo.pendulo => 4000,
          Demo.bombeo => 2400,
          Demo.isometrico => 6000,
          Demo.puno => 2600,
        },
      );

  @override
  void initState() {
    super.initState();
    if (!widget.pausada) _c.repeat();
    CacheBrazo.cargar().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant AnimacionEjercicio old) {
    super.didUpdateWidget(old);
    if (old.demo != widget.demo || old.pausada != widget.pausada) {
      _c.duration = _duracion(widget.demo);
      _c.reset(); // t = 0: posición neutra
      if (!widget.pausada) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _suave(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  // Subir (0–30 %), sostener (30–65 %), bajar (65–95 %)
  static double _subirSostener(double t, double a, {double subir = 0.3, double hasta = 0.65}) {
    if (t < subir) return _suave(t / subir) * a;
    if (t < hasta) return a;
    return (1 - _suave((t - hasta) / 0.3)) * a;
  }

  // (flexión, desviación) de la demostración en el instante t (0–1)
  (double, double) _angulos(double t) {
    final m = widget.meta;
    return switch (widget.demo) {
      Demo.flexion => (_subirSostener(t, m ?? 45), 0.0),
      Demo.extension => (-_subirSostener(t, m ?? 45), 0.0),
      Demo.pendulo => (0.0, (m ?? 18) * sin(2 * pi * t)),
      Demo.bombeo => ((m ?? 30) * sin(2 * pi * t), 0.0),
      Demo.isometrico => (-_subirSostener(t, m ?? 42.5, subir: 0.2, hasta: 0.75), 0.0),
      Demo.puno => (0.0, 0.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!CacheBrazo.listo) {
      return AspectRatio(
        aspectRatio: CuadrosBrazo.ancho / CuadrosBrazo.alto,
        child: Container(
          decoration: BoxDecoration(
            color: Colores.azulSuave.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: CacheBrazo.error != null
              ? Text(CacheBrazo.error!, style: const TextStyle(color: Colores.rojo, fontSize: 12))
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            if (widget.demo == Demo.puno) {
              // Mano abierta → puño → mano abierta
              final f = 1 - (2 * t - 1).abs();
              final i = (f * (CacheBrazo.cuadrosPuno - 1)).round();
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: CuadrosBrazo.ancho / CuadrosBrazo.alto,
                  child: Container(
                    color: Colores.azulSuave.withValues(alpha: 0.55),
                    child: Transform.flip(
                      flipX: widget.izquierda,
                      child: RawImage(image: CacheBrazo.imagen(CacheBrazo.archivoPuno(i)), fit: BoxFit.fill),
                    ),
                  ),
                ),
              );
            }
            final a = _angulos(t);
            return VistaBrazo(
              vista: widget.demo == Demo.pendulo ? TipoVista.superior : TipoVista.lateral,
              lectura: LecturaEnVivo(
                flexion: a.$1,
                desviacion: a.$2,
                estado: EstadoPostura.verde,
                fase: FaseBrazalete.ejercicio,
                antebrazo: 0,
              ),
              colorEstado: Colores.primario,
              izquierda: widget.izquierda,
            );
          },
        ),
        Positioned.fill(
          child: LayoutBuilder(builder: (_, c) {
            final pequena = c.maxWidth < 200;
            final etiqueta = widget.pausada ? 'Posición neutra' : 'Demostración';
            return Stack(
              children: [
                // En miniatura: solo un botón de reproducir; en grande: la etiqueta
                if (pequena && widget.ampliable)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colores.primarioOscuro.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colores.blanco),
                    ),
                  )
                else if (!pequena)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colores.primarioOscuro.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.pausada ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              size: 14, color: Colores.blanco),
                          const SizedBox(width: 4),
                          Text(etiqueta,
                              style: const TextStyle(color: Colores.blanco, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                if (widget.ampliable)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => AnimacionEjercicio.abrir(
                          context,
                          widget.demo,
                          izquierda: widget.izquierda,
                          meta: widget.meta,
                          titulo: widget.titulo ?? 'Demostración',
                          descripcion: widget.descripcion,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
