import '../modelos/datos_brazalete.dart';
import '../modelos/rutina.dart';

// Lo que la app necesita de cualquier brazalete (simulado o real)
abstract class Brazalete {
  String get nombre;
  bool get conectado;
  int get bateria; // %

  // Lecturas en vivo (característica 0001)
  Stream<LecturaEnVivo> get lecturas;

  // Ejercicio en curso (característica 0002)
  Stream<EjercicioEnCurso> get ejercicio;

  // Último ejercicio notificado (null = no hay actividad guiada en curso)
  EjercicioEnCurso? get ejercicioActual;

  // Resultados al terminar rehabilitación (característica 0006)
  Stream<ResultadoRehab> get resultados;

  Future<void> conectar();
  Future<void> desconectar();

  // Envía el modo elegido (característica 0003)
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo});

  // Envía la rutina asignada (característica 0007)
  Future<void> enviarRutina(Rutina rutina);

  // Hora, últimos máximos del paciente y mano (característica 0008)
  Future<void> sincronizar(Map<TipoEjercicio, double>? ultimos, {required bool izquierda});

  // Igual que sostener el botón 5 s: termina o cancela la actividad
  Future<void> cancelar();
}
