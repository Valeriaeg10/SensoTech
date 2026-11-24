import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/rutina.dart';
import 'brazalete.dart';
import 'contrato_ble.dart';

// Error con mensaje para mostrar en pantalla
class ErrorBrazalete implements Exception {
  final String mensaje;
  ErrorBrazalete(this.mensaje);
  @override
  String toString() => mensaje;
}

// Brazalete real por Bluetooth (ESP32 con el firmware SensoTech)
class BrazaleteBle implements Brazalete {
  static final _servicio = Guid(ContratoBle.servicio);
  static final _servicioBateria = Guid('180f');
  static final _nivelBateria = Guid('2a19');

  final _lecturas = StreamController<LecturaEnVivo>.broadcast();
  final _ejercicio = StreamController<EjercicioEnCurso>.broadcast();
  final _resultados = StreamController<ResultadoRehab>.broadcast();
  final _conexion = StreamController<bool>.broadcast();

  BluetoothDevice? _disp;
  BluetoothCharacteristic? _cModo, _cRutina, _cSincro;
  final List<StreamSubscription> _subs = [];
  bool _conectado = false;
  int _bateria = 0;
  EjercicioEnCurso? _actual;

  @override
  String get nombre => _disp?.platformName.isNotEmpty == true ? _disp!.platformName : 'SensoTech';

  @override
  bool get conectado => _conectado;

  @override
  int get bateria => _bateria;

  @override
  Stream<bool> get conexion => _conexion.stream;

  @override
  Stream<LecturaEnVivo> get lecturas => _lecturas.stream;

  @override
  Stream<EjercicioEnCurso> get ejercicio => _ejercicio.stream;

  @override
  EjercicioEnCurso? get ejercicioActual => _actual;

  @override
  Stream<ResultadoRehab> get resultados => _resultados.stream;

  // Busca el brazalete, se conecta y se suscribe a sus datos
  @override
  Future<void> conectar() async {
    if (!await FlutterBluePlus.isSupported) {
      throw ErrorBrazalete('Este dispositivo no tiene Bluetooth');
    }
    // Android: pide encender el Bluetooth si está apagado
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }
      final estado = await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 8), onTimeout: () => BluetoothAdapterState.off);
      if (estado != BluetoothAdapterState.on) throw ErrorBrazalete('Enciende el Bluetooth del celular');
    }

    // Buscar: solo dispositivos con el servicio SensoTech
    final encontrado = Completer<BluetoothDevice?>();
    final sub = FlutterBluePlus.onScanResults.listen((r) {
      if (r.isNotEmpty && !encontrado.isCompleted) encontrado.complete(r.first.device);
    });
    try {
      await FlutterBluePlus.startScan(withServices: [_servicio], timeout: const Duration(seconds: 10));
    } catch (e) {
      await sub.cancel();
      throw ErrorBrazalete('No se pudo buscar el brazalete. Revisa los permisos de Bluetooth y ubicación');
    }
    final disp = await encontrado.future.timeout(const Duration(seconds: 11), onTimeout: () => null);
    await sub.cancel();
    await FlutterBluePlus.stopScan();
    if (disp == null) {
      throw ErrorBrazalete('No se encontró el brazalete. Revisa que esté encendido y cerca');
    }

    try {
      // Uso educativo (ITM): licencia sin ánimo de lucro de FlutterBluePlus
      await disp.connect(license: License.nonprofit, timeout: const Duration(seconds: 15), mtu: null);
      final servicios = await disp.discoverServices();
      BluetoothCharacteristic? c(String uuid) {
        for (final s in servicios) {
          if (s.uuid != _servicio) continue;
          for (final x in s.characteristics) {
            if (x.uuid == Guid(uuid)) return x;
          }
        }
        return null;
      }

      final cAngulos = c(ContratoBle.angulosEnVivo);
      final cEjercicio = c(ContratoBle.ejercicioEnCurso);
      final cResultado = c(ContratoBle.resultadosRehab);
      _cModo = c(ContratoBle.modo);
      _cRutina = c(ContratoBle.rutina);
      _cSincro = c(ContratoBle.sincronizacion);
      if (cAngulos == null || cEjercicio == null || cResultado == null || _cModo == null) {
        throw ErrorBrazalete('El brazalete no tiene el firmware SensoTech actualizado');
      }

      _subs.add(cAngulos.onValueReceived.listen(_alRecibirAngulos));
      _subs.add(cEjercicio.onValueReceived.listen((v) {
        if (v.length < 10) return;
        _actual = ContratoBle.leerEjercicio(v);
        _ejercicio.add(_actual!);
      }));
      _subs.add(cResultado.onValueReceived.listen((v) {
        if (v.length < 13) return;
        final r = ContratoBle.leerResultados(v);
        // Si el brazalete no tenía la hora, se usa la del celular
        _resultados.add(r.fecha.year < 2020
            ? ResultadoRehab(fecha: DateTime.now(), maximos: r.maximos, completa: r.completa)
            : r);
      }));
      await cAngulos.setNotifyValue(true);
      await cEjercicio.setNotifyValue(true);
      await cResultado.setNotifyValue(true);

      // Batería (servicio estándar)
      for (final s in servicios) {
        if (s.uuid != _servicioBateria) continue;
        for (final x in s.characteristics) {
          if (x.uuid != _nivelBateria) continue;
          _subs.add(x.onValueReceived.listen((v) {
            if (v.isNotEmpty) _bateria = v.first;
          }));
          try {
            final v = await x.read();
            if (v.isNotEmpty) _bateria = v.first;
            await x.setNotifyValue(true);
          } catch (_) {}
        }
      }

      _subs.add(disp.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && _conectado) {
          _conectado = false;
          _actual = null;
          _conexion.add(false);
        }
      }));
      _disp = disp;
      _conectado = true;
      _conexion.add(true);
    } on ErrorBrazalete {
      await _limpiar(disp);
      rethrow;
    } catch (e) {
      await _limpiar(disp);
      throw ErrorBrazalete('No se pudo conectar con el brazalete. Intenta de nuevo');
    }
  }

  void _alRecibirAngulos(List<int> v) {
    if (v.length < 8) return;
    final l = ContratoBle.leerAngulos(v);
    // Sin actividad guiada: no hay ejercicio en curso
    if (l.fase == FaseBrazalete.menu || l.fase == FaseBrazalete.midiendo || l.fase == FaseBrazalete.calibrando) {
      _actual = null;
    }
    _lecturas.add(l);
  }

  Future<void> _limpiar(BluetoothDevice d) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      await d.disconnect();
    } catch (_) {}
  }

  @override
  Future<void> desconectar() async {
    final d = _disp;
    _conectado = false;
    _actual = null;
    _disp = null;
    if (d != null) await _limpiar(d);
    _conexion.add(false);
  }

  Future<void> _escribir(BluetoothCharacteristic? c, List<int> bytes) async {
    if (c == null || !_conectado) return;
    try {
      await c.write(bytes);
    } catch (_) {
      throw ErrorBrazalete('No se pudo enviar al brazalete');
    }
  }

  @override
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo}) =>
      _escribir(_cModo, ContratoBle.escribirModo(modo, tipoTrabajo));

  @override
  Future<void> enviarRutina(Rutina rutina) => _escribir(_cRutina, rutina.aBytes());

  @override
  Future<void> sincronizar(Map<TipoEjercicio, double>? ultimos, {required bool izquierda}) =>
      _escribir(_cSincro, ContratoBle.escribirSincronizacion(DateTime.now(), ultimos, izquierda ? 1 : 0));

  // Igual que sostener el botón 5 s: el brazalete termina y manda el resultado
  @override
  Future<void> cancelar() => enviarModo(ModoBrazalete.menu);
}
