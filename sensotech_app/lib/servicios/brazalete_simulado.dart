import 'dart:async';
import 'dart:math';

import '../modelos/datos_brazalete.dart';
import 'brazalete.dart';
import 'contrato_ble.dart';

// Brazalete falso: hace lo mismo que el ESP32 (hoja 2) y pasa todo por el contrato
class BrazaleteSimulado implements Brazalete {
  final _lecturas = StreamController<LecturaEnVivo>.broadcast();
  final _ejercicio = StreamController<EjercicioEnCurso>.broadcast();
  Timer? _timer;
  bool _conectado = false;
  double _t = 0; // segundos desde que conectó
  double _bateria = 100;

  // Prevención
  ModoBrazalete _modo = ModoBrazalete.menu;
  int _minutosPausa = 60;
  double _trabajo = 0; // segundos desde la última pausa
  double _fueraDeRango = 0; // segundos seguidos con |ángulo| > 15°

  // Pausa activa: flexión 30° y extensión 30°, 5 repeticiones cada una
  bool _enPausa = false;
  int _indiceEjercicio = 0;
  int _repeticion = 0;
  bool _llego = false;
  double _tPausa = 0;
  static const _ejerciciosPausa = [TipoEjercicio.flexion, TipoEjercicio.extension];
  static const _objetivoPausa = 30.0;
  static const _repsPausa = 5;

  @override
  String get nombre => 'SensoTech (simulado)';

  @override
  bool get conectado => _conectado;

  @override
  int get bateria => _bateria.round();

  @override
  Stream<LecturaEnVivo> get lecturas => _lecturas.stream;

  @override
  Stream<EjercicioEnCurso> get ejercicio => _ejercicio.stream;

  @override
  Future<void> conectar() async {
    await Future.delayed(const Duration(milliseconds: 800)); // simula la búsqueda
    _conectado = true;
    _t = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  Future<void> desconectar() async {
    _timer?.cancel();
    _timer = null;
    _conectado = false;
    _enPausa = false;
  }

  @override
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo}) async {
    ContratoBle.escribirModo(modo, tipoTrabajo); // mismos bytes que irían al ESP32
    _modo = modo;
    _minutosPausa = tipoTrabajo == 1 ? 45 : 60; // 0 administrativo, 1 repetitivo
    _trabajo = 0;
    _enPausa = false;
  }

  // Solo para pruebas: no esperar 45 o 60 minutos
  void simularPausaAhora() {
    if (_modo == ModoBrazalete.prevencion && !_enPausa) _iniciarPausa();
  }

  // Cada 100 ms (10 veces por segundo, como el contrato)
  void _tick() {
    _t += 0.1;
    _bateria = max(0.0, _bateria - 0.002);
    final antebrazo = 12 * sin(_t * 0.25); // sube y baja el brazo despacio

    if (_enPausa) {
      _tickPausa(antebrazo);
      return;
    }

    final pose = _poseSimulada(_t);
    final temblor = 0.8 * sin(_t * 7) + 0.5 * sin(_t * 13); // pequeño temblor natural
    final flexion = pose.$1 + temblor;
    final desviacion = pose.$2 + temblor * 0.6;

    // Hoja 2: >15° suma tiempo; 4 s = rojo
    if (flexion.abs() > 15) {
      _fueraDeRango += 0.1;
    } else {
      _fueraDeRango = 0;
    }
    final estado = _fueraDeRango == 0
        ? EstadoPostura.verde
        : (_fueraDeRango < 4 ? EstadoPostura.amarillo : EstadoPostura.rojo);

    // Hoja 2: al cumplir el tiempo de trabajo, pausa activa
    if (_modo == ModoBrazalete.prevencion) {
      _trabajo += 0.1;
      if (_trabajo >= _minutosPausa * 60) _iniciarPausa();
    }

    _enviarLectura(flexion, desviacion, estado, FaseBrazalete.midiendo, antebrazo);
  }

  void _iniciarPausa() {
    _enPausa = true;
    _indiceEjercicio = 0;
    _repeticion = 0;
    _llego = false;
    _tPausa = -3; // 3 s para leer la pantalla antes de empezar
    _fueraDeRango = 0;
    _enviarEjercicio();
  }

  // La "persona" hace el ejercicio: subir 1,5 s, sostener 0,5 s, bajar 1,5 s, descansar 0,5 s
  void _tickPausa(double antebrazo) {
    _tPausa += 0.1;
    final tipo = _ejerciciosPausa[_indiceEjercicio];
    final signo = tipo == TipoEjercicio.flexion ? 1.0 : -1.0;

    double magnitud = 0;
    if (_tPausa > 0) {
      final c = _tPausa % 4;
      double suave(double x) => x * x * (3 - 2 * x);
      if (c < 1.5) {
        magnitud = suave(c / 1.5) * (_objetivoPausa + 3);
      } else if (c < 2.0) {
        magnitud = _objetivoPausa + 3;
      } else if (c < 3.5) {
        magnitud = (1 - suave((c - 2.0) / 1.5)) * (_objetivoPausa + 3);
      }
    }
    final flexion = signo * magnitud + 0.5 * sin(_t * 9);

    // Hoja 2: llegó si |ángulo| ≥ objetivo − 5; cuenta al volver a |ángulo| ≤ 8
    if (flexion.abs() >= _objetivoPausa - 5) _llego = true;
    if (_llego && flexion.abs() <= 8) {
      _llego = false;
      _repeticion++;
      if (_repeticion >= _repsPausa) {
        _indiceEjercicio++;
        _repeticion = 0;
        _tPausa = -1.5; // pequeño respiro entre ejercicios
        if (_indiceEjercicio >= _ejerciciosPausa.length) {
          _enPausa = false; // pausa realizada
          _trabajo = 0; // reinicia el tiempo de trabajo
          _enviarLectura(0, 0, EstadoPostura.verde, FaseBrazalete.midiendo, antebrazo);
          return;
        }
      }
      _enviarEjercicio();
    }

    _enviarLectura(flexion, 0, EstadoPostura.verde, FaseBrazalete.pausaActiva, antebrazo);
  }

  void _enviarLectura(double flexion, double desviacion, EstadoPostura estado,
      FaseBrazalete fase, double antebrazo) {
    final lectura = LecturaEnVivo(
      flexion: flexion,
      desviacion: desviacion,
      estado: estado,
      fase: fase,
      antebrazo: antebrazo,
    );
    // Ida y vuelta por bytes, igual que con el brazalete real
    _lecturas.add(ContratoBle.leerAngulos(ContratoBle.escribirAngulos(lectura)));
  }

  void _enviarEjercicio() {
    final e = EjercicioEnCurso(
      tipo: _ejerciciosPausa[_indiceEjercicio],
      objetivo: _objetivoPausa,
      repeticion: _repeticion,
      repeticionesTotal: _repsPausa,
      serie: _indiceEjercicio + 1,
      seriesTotal: _ejerciciosPausa.length,
      descanso: 0,
    );
    _ejercicio.add(ContratoBle.leerEjercicio(ContratoBle.escribirEjercicio(e)));
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
