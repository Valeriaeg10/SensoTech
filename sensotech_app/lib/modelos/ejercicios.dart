import 'datos_brazalete.dart';

// Ejercicios definidos para SensoTech (rehabilitación: r1–r3 · prevención: p1–p3)
enum IdEjercicio { r1Tendones, r2Extension, r3Pendulo, p1Bombeo, p2Isometrico, p3Dedos }

// Cómo se ve la animación de demostración
enum Demo { flexion, extension, pendulo, bombeo, isometrico, puno }

class DefEjercicio {
  final IdEjercicio id;
  final String nombre; // nombre técnico
  final String instruccion; // explicación sencilla para el paciente
  final String mecanica; // cómo cuenta el brazalete (para el fisio y el informe)
  final List<TipoEjercicio> movimientos;
  final double metaMin; // grados
  final double metaMax;
  final double? riesgo; // por encima de este ángulo: zona roja
  final int sostener; // segundos sosteniendo la postura (0 = no aplica)
  final int seriesBase;
  final int repsBase;
  final Demo demo;

  const DefEjercicio({
    required this.id,
    required this.nombre,
    required this.instruccion,
    required this.mecanica,
    required this.movimientos,
    required this.metaMin,
    required this.metaMax,
    required this.riesgo,
    required this.sostener,
    required this.seriesBase,
    required this.repsBase,
    required this.demo,
  });

  bool get esRehabilitacion => id.index <= 2;

  String get dosis => switch (id) {
        IdEjercicio.p2Isometrico => '$seriesBase repeticiones de $sostener s',
        IdEjercicio.p3Dedos => 'Durante $sostener s',
        _ => '$seriesBase series de $repsBase repeticiones',
      };

  String get meta => switch (id) {
        IdEjercicio.p1Bombeo => '${metaMin.round()}° de flexión y de extensión',
        IdEjercicio.p3Dedos => 'Muñeca recta (máximo ${metaMax.round()}°)',
        _ => '${metaMin.round()}° a ${metaMax.round()}°',
      };
}

const catalogo = <IdEjercicio, DefEjercicio>{
  // ---------- Rehabilitación ----------
  IdEjercicio.r1Tendones: DefEjercicio(
    id: IdEjercicio.r1Tendones,
    nombre: 'Deslizamiento tendinoso en flexión palmar',
    instruccion: 'Realiza flexión palmar lenta hasta la meta, sostén 3 segundos '
        'y regresa a la posición neutra.',
    mecanica: 'Cuenta 1 repetición al llegar a la meta, sostener 3 s y volver a 0°.',
    movimientos: [TipoEjercicio.flexion],
    metaMin: 40,
    metaMax: 45,
    riesgo: null,
    sostener: 3,
    seriesBase: 3,
    repsBase: 10,
    demo: Demo.flexion,
  ),
  IdEjercicio.r2Extension: DefEjercicio(
    id: IdEjercicio.r2Extension,
    nombre: 'Extensión de muñeca sostenida',
    instruccion: 'Realiza extensión de muñeca sin forzar hasta la meta, sostén 10 segundos '
        'y regresa a la posición neutra.',
    mecanica: 'Cuenta 1 repetición al llegar a la meta y sostener 10 s.',
    movimientos: [TipoEjercicio.extension],
    metaMin: 40,
    metaMax: 45,
    riesgo: null,
    sostener: 10,
    seriesBase: 2,
    repsBase: 10,
    demo: Demo.extension,
  ),
  IdEjercicio.r3Pendulo: DefEjercicio(
    id: IdEjercicio.r3Pendulo,
    nombre: 'Desviación radial y cubital controlada (péndulo)',
    instruccion: 'Con el antebrazo en pronación, alterna desviación radial y desviación cubital '
        'de forma controlada, sin salir de la zona segura.',
    mecanica: 'Alterna desviación radial y cubital. Por encima de 20° la mano se pone roja: '
        '"Has alcanzado el límite de seguridad".',
    movimientos: [TipoEjercicio.radial, TipoEjercicio.cubital],
    metaMin: 10,
    metaMax: 18,
    riesgo: 20,
    sostener: 0,
    seriesBase: 2,
    repsBase: 15,
    demo: Demo.pendulo,
  ),
  // ---------- Prevención (pausa activa) ----------
  IdEjercicio.p1Bombeo: DefEjercicio(
    id: IdEjercicio.p1Bombeo,
    nombre: 'Bombeo de flexoextensión',
    instruccion: 'Alterna flexión palmar y extensión de forma rítmica y continua, '
        'sin superar el límite de seguridad.',
    mecanica: 'Cada paso de +30° a −30° cuenta 1 repetición. Por encima de 50° avisa que baje la intensidad.',
    movimientos: [TipoEjercicio.flexion, TipoEjercicio.extension],
    metaMin: 30,
    metaMax: 30,
    riesgo: 50,
    sostener: 0,
    seriesBase: 2,
    repsBase: 15,
    demo: Demo.bombeo,
  ),
  IdEjercicio.p2Isometrico: DefEjercicio(
    id: IdEjercicio.p2Isometrico,
    nombre: 'Isométrico en extensión',
    instruccion: 'Lleva la muñeca en extensión hasta la zona meta (40° a 45°) '
        'y mantén la posición sin superarla (contracción isométrica).',
    mecanica: 'Sostener entre 40° y 45° de extensión durante 20 s. Por encima de 45° pide aflojar.',
    movimientos: [TipoEjercicio.extension],
    metaMin: 40,
    metaMax: 45,
    riesgo: 45,
    sostener: 20,
    seriesBase: 2,
    repsBase: 1,
    demo: Demo.isometrico,
  ),
  IdEjercicio.p3Dedos: DefEjercicio(
    id: IdEjercicio.p3Dedos,
    nombre: 'Activación de dedos en posición neutra',
    instruccion: 'Con la muñeca en posición neutra, realiza flexión de los dedos (puño suave) '
        'y luego extensión completa de los dedos.',
    mecanica: 'Abrir y cerrar la mano 20 s. Si la muñeca se dobla más de 12°, alerta.',
    movimientos: [TipoEjercicio.flexion, TipoEjercicio.extension],
    metaMin: 0,
    metaMax: 12,
    riesgo: 12,
    sostener: 20,
    seriesBase: 1,
    repsBase: 1,
    demo: Demo.puno,
  ),
};

const ejerciciosRehab = [IdEjercicio.r1Tendones, IdEjercicio.r2Extension, IdEjercicio.r3Pendulo];
const ejerciciosPrevencion = [IdEjercicio.p1Bombeo, IdEjercicio.p2Isometrico, IdEjercicio.p3Dedos];

// Meta progresiva (hoja 3): último máximo + 5°, sin pasar la meta máxima segura del ejercicio
double metaProgresiva(DefEjercicio d, Map<TipoEjercicio, double>? ultimos) {
  if (ultimos == null) return d.metaMin;
  final mov = d.movimientos.first;
  final ultimo = ultimos[mov];
  if (ultimo == null) return d.metaMin;
  final v = ultimo + 5;
  return v > d.metaMax ? d.metaMax : (v < 5 ? 5 : v);
}
