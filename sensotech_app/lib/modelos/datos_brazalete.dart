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
  final double flexion; // mano − antebrazo: + flexión, − extensión
  final double desviacion; // mano − antebrazo: + pulgar, − meñique
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

// Ejercicio de la pausa activa o la rehabilitación
enum TipoEjercicio { flexion, extension, pulgar, menique }

extension TextoEjercicio on TipoEjercicio {
  String get texto => switch (this) {
        TipoEjercicio.flexion => 'Flexión',
        TipoEjercicio.extension => 'Extensión',
        TipoEjercicio.pulgar => 'Hacia el pulgar',
        TipoEjercicio.menique => 'Hacia el meñique',
      };

  String get instruccion => switch (this) {
        TipoEjercicio.flexion => 'Dobla la mano hacia abajo',
        TipoEjercicio.extension => 'Lleva la mano hacia arriba',
        TipoEjercicio.pulgar => 'Gira la mano hacia el pulgar',
        TipoEjercicio.menique => 'Gira la mano hacia el meñique',
      };
}

// Ejercicio en curso (característica 0002, 8 bytes)
class EjercicioEnCurso {
  final TipoEjercicio tipo;
  final double objetivo; // grados
  final int repeticion;
  final int repeticionesTotal;
  final int serie;
  final int seriesTotal;
  final int descanso; // segundos restantes (0 = sin descanso)

  const EjercicioEnCurso({
    required this.tipo,
    required this.objetivo,
    required this.repeticion,
    required this.repeticionesTotal,
    required this.serie,
    required this.seriesTotal,
    required this.descanso,
  });
}
