import '../modelos/datos_brazalete.dart';

// Lo que la app necesita de cualquier brazalete (simulado o real)
abstract class Brazalete {
  String get nombre;
  bool get conectado;
  int get bateria; // %

  // Lecturas en vivo (característica 0001)
  Stream<LecturaEnVivo> get lecturas;

  Future<void> conectar();
  Future<void> desconectar();
}
