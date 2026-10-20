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

    final flexion = _flexionSimulada(_t);
    final desviacion = 6 * sin(_t * 0.7);
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

  // Ciclo de 20 s: 12 s normal, luego 8 s con la muñeca doblada
  double _flexionSimulada(double t) {
    final c = t % 20;
    final normal = 8 * sin(t * 1.2);
    if (c < 12) return normal;
    final subida = sin((c - 12) / 8 * pi); // 0 -> 1 -> 0
    return normal * (1 - subida) + 26 * subida;
  }
}
