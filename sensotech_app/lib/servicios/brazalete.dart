import '../modelos/datos_brazalete.dart';

// Lo que la app necesita de cualquier brazalete (simulado o real)
abstract class Brazalete {
  String get nombre;
  bool get conectado;
  int get bateria; // %

  // Lecturas en vivo (característica 0001)
  Stream<LecturaEnVivo> get lecturas;

  // Ejercicio en curso (característica 0002)
  Stream<EjercicioEnCurso> get ejercicio;

  Future<void> conectar();
  Future<void> desconectar();

  // Envía el modo elegido (característica 0003)
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo});
}
