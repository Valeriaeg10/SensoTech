// Estado del semáforo (byte 4 de la característica 0001)
enum EstadoPostura { verde, amarillo, rojo }

// Fase del brazalete (byte 5 de la característica 0001)
enum FaseBrazalete {
  menu,
  calibrando,
  midiendo,
  pausaActiva,
  ejercicio,
  descanso,
  evaluacion,
}

// Modo del brazalete (característica 0003, byte 0)
enum ModoBrazalete { menu, prevencion, rehabilitacion }

// Una lectura en vivo (llega 10 veces por segundo)
class LecturaEnVivo {
  final double flexion; // mano − antebrazo: + flexión palmar, − extensión
  final double desviacion; // mano − antebrazo: + desviación radial, − desviación cubital
  final EstadoPostura estado;
  final FaseBrazalete fase;
  final double antebrazo; // IMU 1: + brazo arriba, − brazo abajo

  const LecturaEnVivo({
    required this.flexion,
    required this.desviacion,
    required this.estado,
    required this.fase,
    required this.antebrazo,
  });
}

// Movimientos de la muñeca (nombres técnicos)
enum TipoEjercicio { flexion, extension, radial, cubital }

extension TextoEjercicio on TipoEjercicio {
  String get texto => switch (this) {
        TipoEjercicio.flexion => 'Flexión palmar',
        TipoEjercicio.extension => 'Extensión',
        TipoEjercicio.radial => 'Desviación radial',
        TipoEjercicio.cubital => 'Desviación cubital',
      };

  String get corto => switch (this) {
        TipoEjercicio.flexion => 'Flexión',
        TipoEjercicio.extension => 'Extensión',
        TipoEjercicio.radial => 'D. radial',
        TipoEjercicio.cubital => 'D. cubital',
      };

  // Explicación sencilla para el paciente (siempre junto a la animación)
  String get instruccion => switch (this) {
        TipoEjercicio.flexion => 'Lleva la muñeca en flexión palmar',
        TipoEjercicio.extension => 'Lleva la muñeca en extensión (flexión dorsal)',
        TipoEjercicio.radial => 'Con el antebrazo en pronación, desvía la muñeca en sentido radial',
        TipoEjercicio.cubital => 'Con el antebrazo en pronación, desvía la muñeca en sentido cubital',
      };

  // Ángulo medido en esta dirección (positivo = hacia el movimiento)
  double desde(LecturaEnVivo l) => switch (this) {
        TipoEjercicio.flexion => l.flexion,
        TipoEjercicio.extension => -l.flexion,
        TipoEjercicio.radial => l.desviacion,
        TipoEjercicio.cubital => -l.desviacion,
      };
}

// Zona del ejercicio en curso (byte 9 de la característica 0002)
enum ZonaEjercicio { normal, enMeta, riesgo }

// Ejercicio en curso (característica 0002, 10 bytes)
class EjercicioEnCurso {
  final int codigo; // 0–5 ejercicio del catálogo · 10–13 evaluación de un movimiento
  final double objetivo; // grados con signo: + flexión / + radial
  final int repeticion;
  final int repeticionesTotal;
  final int serie;
  final int seriesTotal;
  final int descanso; // segundos restantes de descanso (0 = sin descanso)
  final int sostener; // segundos que faltan sosteniendo la postura
  final ZonaEjercicio zona;

  const EjercicioEnCurso({
    required this.codigo,
    required this.objetivo,
    required this.repeticion,
    required this.repeticionesTotal,
    required this.serie,
    required this.seriesTotal,
    required this.descanso,
    required this.sostener,
    required this.zona,
  });

  bool get esEvaluacion => codigo >= 10;

  // Movimiento que se evalúa (solo si esEvaluacion)
  TipoEjercicio get movimientoEvaluado => TipoEjercicio.values[(codigo - 10).clamp(0, 3)];
}

// Resultados de una sesión de rehabilitación (característica 0006)
class ResultadoRehab {
  final DateTime fecha;
  final Map<TipoEjercicio, double> maximos;
  final bool completa;

  const ResultadoRehab({required this.fecha, required this.maximos, required this.completa});
}
