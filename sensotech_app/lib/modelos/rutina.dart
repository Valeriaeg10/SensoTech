import 'datos_brazalete.dart';
import 'ejercicios.dart';

// Un ejercicio de la rutina (4 bytes en la característica 0007)
class EjercicioRutina {
  final IdEjercicio id;
  final int series;
  final int repeticiones;
  final double? meta; // null = meta progresiva (la calcula el brazalete)

  const EjercicioRutina({required this.id, required this.series, required this.repeticiones, this.meta});

  DefEjercicio get def => catalogo[id]!;

  String get textoMeta => meta == null ? 'Progresiva' : '${meta!.round()}°';

  Map<String, dynamic> aMapa() => {'id': id.index, 'series': series, 'reps': repeticiones, 'meta': meta};

  factory EjercicioRutina.desdeMapa(Map<String, dynamic> m) => EjercicioRutina(
        id: IdEjercicio.values[m['id'] as int],
        series: m['series'] as int,
        repeticiones: m['reps'] as int,
        meta: (m['meta'] as num?)?.toDouble(),
      );
}

// Rutina de rehabilitación que el fisio asigna a un paciente
class Rutina {
  final List<EjercicioRutina> ejercicios;
  final int descanso; // segundos entre series
  final DateTime actualizada;
  final String? nota; // indicación del fisio

  const Rutina({required this.ejercicios, required this.descanso, required this.actualizada, this.nota});

  // Si el fisio no ha asignado una: los 3 ejercicios definidos, meta progresiva
  static Rutina predefinida() => Rutina(
        ejercicios: [
          for (final id in ejerciciosRehab)
            EjercicioRutina(id: id, series: catalogo[id]!.seriesBase, repeticiones: catalogo[id]!.repsBase),
        ],
        descanso: 30,
        actualizada: DateTime(2026),
      );

  // Bytes para la característica 0007: cantidad, descanso y 4 bytes por ejercicio
  List<int> aBytes() => [
        ejercicios.length,
        descanso,
        for (final e in ejercicios) ...[e.id.index, e.series, e.repeticiones, (e.meta ?? 0).round()],
      ];

  Map<String, dynamic> aMapa() => {
        'ejercicios': ejercicios.map((e) => e.aMapa()).toList(),
        'descanso': descanso,
        'actualizada': actualizada.toIso8601String(),
        'nota': nota,
      };

  factory Rutina.desdeMapa(Map<String, dynamic> m) => Rutina(
        ejercicios: (m['ejercicios'] as List)
            .map((e) => EjercicioRutina.desdeMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
        descanso: m['descanso'] as int,
        actualizada: DateTime.parse(m['actualizada'] as String),
        nota: m['nota'] as String?,
      );
}

// Sesión de rehabilitación guardada (resultados del brazalete + encuesta de dolor)
class SesionRehab {
  final String perfilId;
  final DateTime fecha;
  final double flexion;
  final double extension;
  final double radial;
  final double cubital;
  final bool completa;
  final int? dolorAntes; // EVA 0–10
  final int? dolorDespues; // EVA 0–10
  final List<EjercicioRutina> realizados; // lo que se alcanzó a hacer

  const SesionRehab({
    required this.perfilId,
    required this.fecha,
    required this.flexion,
    required this.extension,
    required this.radial,
    required this.cubital,
    required this.completa,
    this.dolorAntes,
    this.dolorDespues,
    this.realizados = const [],
  });

  double maximo(TipoEjercicio t) => switch (t) {
        TipoEjercicio.flexion => flexion,
        TipoEjercicio.extension => extension,
        TipoEjercicio.radial => radial,
        TipoEjercicio.cubital => cubital,
      };

  Map<TipoEjercicio, double> get maximos => {for (final t in TipoEjercicio.values) t: maximo(t)};

  Map<String, dynamic> aMapa() => {
        'perfilId': perfilId,
        'fecha': fecha.toIso8601String(),
        'flexion': flexion,
        'extension': extension,
        'radial': radial,
        'cubital': cubital,
        'completa': completa,
        'dolorAntes': dolorAntes,
        'dolorDespues': dolorDespues,
        'realizados': realizados.map((e) => e.aMapa()).toList(),
      };

  factory SesionRehab.desdeMapa(Map<String, dynamic> m) => SesionRehab(
        perfilId: m['perfilId'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        flexion: (m['flexion'] as num).toDouble(),
        extension: (m['extension'] as num).toDouble(),
        radial: ((m['radial'] ?? m['pulgar']) as num).toDouble(), // compatible con datos viejos
        cubital: ((m['cubital'] ?? m['menique']) as num).toDouble(),
        completa: m['completa'] as bool,
        dolorAntes: m['dolorAntes'] as int?,
        dolorDespues: m['dolorDespues'] as int?,
        realizados: ((m['realizados'] as List?) ?? [])
            .map((e) => EjercicioRutina.desdeMapa(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

// Rango articular normal de referencia (para las barras del fisio)
const rangoReferencia = {
  TipoEjercicio.flexion: 80.0,
  TipoEjercicio.extension: 70.0,
  TipoEjercicio.radial: 20.0,
  TipoEjercicio.cubital: 30.0,
};
