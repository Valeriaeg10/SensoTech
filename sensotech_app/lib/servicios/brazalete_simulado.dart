import 'dart:async';
import 'dart:math';

import '../modelos/datos_brazalete.dart';
import 'brazalete.dart';
import 'contrato_ble.dart';

// Brazalete falso: genera datos como el ESP32 y los pasa por el contrato
class BrazaleteSimulado implements Brazalete {
  final _control = StreamController<LecturaEnVivo>.broadcast();
  Timer? _timer;
  bool _conectado = false;
  double _t = 0; // segundos desde que conectó
  double _fueraDeRango = 0; // segundos seguidos con |ángulo| > 15°
  double _bateria = 100;

  @override
  String get nombre => 'SensoTech (simulado)';

  @override
  bool get conectado => _conectado;

  @override
  int get bateria => _bateria.round();

  @override
  Stream<LecturaEnVivo> get lecturas => _control.stream;

  @override
  Future<void> conectar() async {
    await Future.delayed(const Duration(milliseconds: 800)); // simula la búsqueda
    _conectado = true;
    _t = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  ModoBrazalete _modo = ModoBrazalete.menu;
  ModoBrazalete get modo => _modo;

  @override
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo}) async {
    ContratoBle.escribirModo(modo, tipoTrabajo); // mismos bytes que iría al ESP32
    _modo = modo;
  }

  @override
  Future<void> desconectar() async {
    _timer?.cancel();
    _timer = null;
    _conectado = false;
  }

  // Cada 100 ms (10 veces por segundo, como el contrato)
  void _tick() {
    _t += 0.1;
    _bateria = max(0.0, _bateria - 0.002);

    final pose = _poseSimulada(_t);
    final temblor = 0.8 * sin(_t * 7) + 0.5 * sin(_t * 13); // pequeño temblor natural
    final flexion = pose.$1 + temblor;
    final desviacion = pose.$2 + temblor * 0.6;
    final antebrazo = 12 * sin(_t * 0.25); // sube y baja el brazo despacio

    // Misma regla de la hoja 2: >15° suma tiempo; 4 s = rojo
    if (flexion.abs() > 15) {
      _fueraDeRango += 0.1;
    } else {
      _fueraDeRango = 0;
    }

    EstadoPostura estado;
    if (_fueraDeRango == 0) {
      estado = EstadoPostura.verde;
    } else if (_fueraDeRango < 4) {
      estado = EstadoPostura.amarillo;
    } else {
      estado = EstadoPostura.rojo;
    }

    final lectura = LecturaEnVivo(
      flexion: flexion,
      desviacion: desviacion,
      estado: estado,
      fase: FaseBrazalete.midiendo,
      antebrazo: antebrazo,
    );

    // Ida y vuelta por bytes, igual que con el brazalete real
    final bytes = ContratoBle.escribirAngulos(lectura);
    _control.add(ContratoBle.leerAngulos(bytes));
  }

  // Posturas reales en un ciclo de 20 s: (segundo, flexión, desviación)
  static const _poses = [
    (0.0, 0.0, 0.0), // descanso
    (3.0, 0.0, 0.0),
    (4.2, -12.0, -8.0), // escribiendo en teclado
    (7.5, -12.0, -8.0),
    (8.5, -8.0, -18.0), // usando el mouse (hacia el meñique)
    (10.5, -8.0, -18.0),
    (11.5, 5.0, 12.0), // alcanza algo (hacia el pulgar)
    (12.5, 5.0, 12.0),
    (13.5, 26.0, -5.0), // muñeca doblada: mala postura
    (18.5, 26.0, -5.0),
    (19.5, 0.0, 0.0),
    (20.0, 0.0, 0.0),
  ];

  // Pasa suave de una postura a la siguiente
  (double, double) _poseSimulada(double t) {
    final c = t % 20;
    for (var i = 0; i < _poses.length - 1; i++) {
      final a = _poses[i];
      final b = _poses[i + 1];
      if (c >= a.$1 && c <= b.$1) {
        final x = (c - a.$1) / (b.$1 - a.$1);
        final suave = x * x * (3 - 2 * x); // curva en S
        return (a.$2 + (b.$2 - a.$2) * suave, a.$3 + (b.$3 - a.$3) * suave);
      }
    }
    return (0.0, 0.0);
  }
}
