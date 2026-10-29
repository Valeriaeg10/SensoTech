import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'cuadros_brazo.dart';

// Carga las imágenes del brazo en memoria una sola vez (así cambian al instante en el celular)
class CacheBrazo {
  static final Map<String, ui.Image> _imagenes = {};
  static Future<void>? _carga;
  static String? error; // si una imagen falta, aquí queda cuál

  static String archivo(bool lateral, int a) => 'assets/brazo/${lateral ? 'lat' : 'sup'}_$a.png';

  // Puño (activación de dedos), de mano abierta (0) a cerrada (4)
  static const cuadrosPuno = 5;
  static String archivoPuno(int i) => 'assets/brazo/pun_$i.png';

  static List<String> get _todos => [
        for (var a = CuadrosBrazo.latMin; a <= CuadrosBrazo.latMax; a += CuadrosBrazo.paso) archivo(true, a),
        for (var a = CuadrosBrazo.supMin; a <= CuadrosBrazo.supMax; a += CuadrosBrazo.paso) archivo(false, a),
        for (var i = 0; i < cuadrosPuno; i++) archivoPuno(i),
      ];

  static bool get listo => error == null && _imagenes.length == _todos.length;

  // Se puede llamar muchas veces: solo carga la primera
  static Future<void> cargar() => _carga ??= _cargarTodo();

  static Future<void> _cargarTodo() async {
    for (final ruta in _todos) {
      try {
        final datos = await rootBundle.load(ruta);
        final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
        _imagenes[ruta] = (await codec.getNextFrame()).image;
      } catch (_) {
        error = 'No se encontró $ruta. Revisa assets/brazo/ en pubspec.yaml';
        return;
      }
    }
  }

  static ui.Image? imagen(String ruta) => _imagenes[ruta];
}
