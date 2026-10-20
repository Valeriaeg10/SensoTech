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
