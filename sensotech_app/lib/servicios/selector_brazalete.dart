import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/rutina.dart';
import 'brazalete.dart';
import 'brazalete_ble.dart';
import 'brazalete_simulado.dart';

// Un solo brazalete para la app: el real (Bluetooth) o el simulado (pruebas sin hardware)
class SelectorBrazalete implements Brazalete {
  final BrazaleteBle real = BrazaleteBle();
  final BrazaleteSimulado simulado = BrazaleteSimulado();
  bool usarSimulado = false;

  final _conexion = StreamController<bool>.broadcast();

  SelectorBrazalete() {
    real.conexion.listen((v) => !usarSimulado ? _conexion.add(v) : null);
    simulado.conexion.listen((v) => usarSimulado ? _conexion.add(v) : null);
  }

  Brazalete get actual => usarSimulado ? simulado : real;

  // Si se está usando el simulado (para mostrar "Probar pausa ahora")
  BrazaleteSimulado? get simuladoActivo => usarSimulado ? simulado : null;

  Future<void> cargarPreferencia() async {
    final p = await SharedPreferences.getInstance();
    usarSimulado = p.getBool('usar_simulado') ?? false;
  }

  Future<void> elegirSimulado(bool valor) async {
    if (actual.conectado) await actual.desconectar();
    usarSimulado = valor;
    final p = await SharedPreferences.getInstance();
    await p.setBool('usar_simulado', valor);
  }

  @override
  String get nombre => actual.nombre;
  @override
  bool get conectado => actual.conectado;
  @override
  int get bateria => actual.bateria;
  @override
  Stream<bool> get conexion => _conexion.stream;
  @override
  Stream<LecturaEnVivo> get lecturas => actual.lecturas;
  @override
  Stream<EjercicioEnCurso> get ejercicio => actual.ejercicio;
  @override
  EjercicioEnCurso? get ejercicioActual => actual.ejercicioActual;
  @override
  Stream<ResultadoRehab> get resultados => actual.resultados;
  @override
  Future<void> conectar() => actual.conectar();
  @override
  Future<void> desconectar() => actual.desconectar();
  @override
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo}) => actual.enviarModo(modo, tipoTrabajo: tipoTrabajo);
  @override
  Future<void> enviarRutina(Rutina rutina) => actual.enviarRutina(rutina);
  @override
  Future<void> sincronizar(Map<TipoEjercicio, double>? ultimos, {required bool izquierda}) =>
      actual.sincronizar(ultimos, izquierda: izquierda);
  @override
  Future<void> cancelar() => actual.cancelar();
}
