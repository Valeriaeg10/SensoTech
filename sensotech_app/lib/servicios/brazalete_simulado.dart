import 'dart:async';
import 'dart:math';

import '../modelos/datos_brazalete.dart';
import '../modelos/ejercicios.dart';
import '../modelos/rutina.dart';
import 'brazalete.dart';
import 'contrato_ble.dart';

// Cómo cuenta el brazalete cada clase de ejercicio (hojas 2 y 3 del diagrama)
enum _Clase {
  repeticion, // llegar a la meta, sostener y volver a 0° (R1, R2)
  alterno, // ir de un lado al otro; cada llegada al lado contrario es 1 repetición (R3, P1)
  sostenido, // mantener dentro de la zona meta un tiempo (P2)
  neutro, // mantener la muñeca recta un tiempo (P3)
  evaluacion, // medir el ángulo máximo de un movimiento
}

class _Paso {
  final int codigo; // 0–5 catálogo · 10–13 evaluación
  final _Clase clase;
  final List<TipoEjercicio> movs;
  final DefEjercicio? def;
  final double? metaFija; // null = progresiva
  final double? riesgo;
  final int series;
  final int reps;
  final int sostener;

  const _Paso({
    required this.codigo,
    required this.clase,
    required this.movs,
    this.def,
    this.metaFija,
    this.riesgo,
    required this.series,
    required this.reps,
    required this.sostener,
  });
}

// Brazalete falso: hace lo mismo que el ESP32 y pasa todo por el contrato BLE
class BrazaleteSimulado implements Brazalete {
  // Para mostrar la app sin esperar: menos repeticiones, sostener y descansar menos.
  // El brazalete real usa las cantidades completas.
  static bool abreviado = true;

  final _lecturas = StreamController<LecturaEnVivo>.broadcast();
  final _ejercicio = StreamController<EjercicioEnCurso>.broadcast();
  final _resultados = StreamController<ResultadoRehab>.broadcast();
  final _azar = Random();
  Timer? _timer;
  bool _conectado = false;
  double _t = 0; // segundos desde que conectó
  double _bateria = 100;

  // Prevención
  ModoBrazalete _modo = ModoBrazalete.menu;
  int _minutosPausa = 60;
  double _trabajo = 0; // segundos desde la última pausa
  double _fueraDeRango = 0; // segundos seguidos con |ángulo| > 15°

  // Datos recibidos de la app
  Map<TipoEjercicio, double>? _ultimos; // 0008
  int _descansoRutina = 30; // 0007
  List<(int, int, int, int)> _rutina = const []; // 0007

  // Actividad guiada (pausa activa o sesión de rehabilitación)
  List<_Paso> _pasos = const [];
  bool _activo = false;
  bool _rehab = false;
  int _iPaso = 0;
  double _calibrando = 0;
  int _serie = 1;
  int _rep = 0;
  double _meta = 0;
  double _tp = 0; // reloj del "paciente" dentro del ejercicio
  double _tLlego = 0;
  double _sost = 0; // segundos que faltan sosteniendo
  bool _llego = false;
  int _lado = 0; // alterno: 1 = último lado alcanzado fue el primero, −1 = el segundo
  double _descanso = 0;
  ZonaEjercicio _zona = ZonaEjercicio.normal;
  final Map<TipoEjercicio, double> _maximos = {};
  Map<TipoEjercicio, double> _capacidad = const {};
  EjercicioEnCurso? _actual;
  List<int>? _bytesActual;

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
  EjercicioEnCurso? get ejercicioActual => _actual;

  @override
  Stream<ResultadoRehab> get resultados => _resultados.stream;

  @override
  Future<void> conectar() async {
    await Future.delayed(const Duration(milliseconds: 800)); // simula la búsqueda
    _conectado = true;
    _t = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  Future<void> desconectar() async {
    _timer?.cancel();
    _timer = null;
    _conectado = false;
    _detener();
  }

  @override
  Future<void> enviarModo(ModoBrazalete modo, {int? tipoTrabajo}) async {
    ContratoBle.escribirModo(modo, tipoTrabajo); // mismos bytes que irían al ESP32
    if (modo != _modo) _detener();
    _modo = modo;
    _minutosPausa = tipoTrabajo == 1 ? 45 : 60; // 0 administrativo, 1 repetitivo
    _trabajo = 0;
  }

  @override
  Future<void> sincronizar(Map<TipoEjercicio, double>? ultimos, {required bool izquierda}) async {
    final bytes = ContratoBle.escribirSincronizacion(DateTime.now(), ultimos, izquierda ? 1 : 0);
    _ultimos = ContratoBle.leerSincronizacion(bytes).$2;
  }

  @override
  Future<void> enviarRutina(Rutina rutina) async {
    final r = ContratoBle.leerRutina(rutina.aBytes());
    _descansoRutina = r.$1;
    _rutina = r.$2;
    if (_modo == ModoBrazalete.rehabilitacion) _iniciarRehab();
  }

  @override
  Future<void> cancelar() async {
    if (_activo) _terminar(completa: false);
  }

  // Solo para pruebas: no esperar 45 o 60 minutos
  void simularPausaAhora() {
    if (_modo == ModoBrazalete.prevencion && !_activo) _iniciarPausa();
  }

  // ---------------- Construcción de la actividad ----------------

  _Paso _desdeDef(DefEjercicio d, {int? series, int? reps, double? meta}) {
    final clase = switch (d.id) {
      IdEjercicio.r1Tendones || IdEjercicio.r2Extension => _Clase.repeticion,
      IdEjercicio.r3Pendulo || IdEjercicio.p1Bombeo => _Clase.alterno,
      IdEjercicio.p2Isometrico => _Clase.sostenido,
      IdEjercicio.p3Dedos => _Clase.neutro,
    };
    var s = series ?? d.seriesBase;
    var r = reps ?? d.repsBase;
    var h = d.sostener;
    if (d.id == IdEjercicio.p2Isometrico) {
      s = 1;
      r = d.seriesBase; // 2 repeticiones de 20 s
    }
    if (d.id == IdEjercicio.p3Dedos) {
      s = 1;
      r = 1;
    }
    if (abreviado) {
      s = min(s, 2);
      r = min(r, clase == _Clase.alterno ? 6 : 3);
      h = min(h, clase == _Clase.repeticion ? 5 : 10);
    }
    return _Paso(
      codigo: d.id.index,
      clase: clase,
      movs: d.movimientos,
      def: d,
      metaFija: meta ?? (d.esRehabilitacion ? null : d.metaMin),
      riesgo: d.riesgo,
      series: s,
      reps: r,
      sostener: h,
    );
  }

  List<_Paso> _evaluacion() => [
        for (final t in TipoEjercicio.values)
          _Paso(
            codigo: 10 + t.index,
            clase: _Clase.evaluacion,
            movs: [t],
            series: 1,
            reps: 1,
            sostener: abreviado ? 6 : 10,
          ),
      ];

  void _iniciarPausa() {
    _iniciar([for (final id in ejerciciosPrevencion) _desdeDef(catalogo[id]!)], rehab: false);
  }

  void _iniciarRehab() {
    final pasos = <_Paso>[];
    if (_ultimos == null) pasos.addAll(_evaluacion()); // línea base
    for (final e in _rutina) {
      if (e.$1 >= IdEjercicio.values.length) continue;
      pasos.add(_desdeDef(
        catalogo[IdEjercicio.values[e.$1]]!,
        series: e.$2,
        reps: e.$3,
        meta: e.$4 == 0 ? null : e.$4.toDouble(),
      ));
    }
    pasos.addAll(_evaluacion()); // evaluación final

    // Hasta dónde puede llegar hoy el "paciente" simulado
    const base = {
      TipoEjercicio.flexion: 42.0,
      TipoEjercicio.extension: 36.0,
      TipoEjercicio.radial: 12.0,
      TipoEjercicio.cubital: 18.0,
    };
    _capacidad = {
      for (final t in TipoEjercicio.values)
        t: min(rangoReferencia[t]!, (_ultimos?[t] ?? base[t]!) + 1 + _azar.nextDouble() * 3),
    };
    _iniciar(pasos, rehab: true);
  }

  void _iniciar(List<_Paso> pasos, {required bool rehab}) {
    _pasos = pasos;
    _rehab = rehab;
    _activo = true;
    _iPaso = 0;
    _maximos.clear();
    _calibrando = rehab ? 5 : 0; // hoja 3: 5 s quieto para calibrar
    _fueraDeRango = 0;
    _bytesActual = null;
    _empezarPaso();
  }

  void _empezarPaso() {
    final p = _pasos[_iPaso];
    _serie = 1;
    _rep = 0;
    if (p.clase == _Clase.evaluacion) {
      _meta = _ultimos?[p.movs.first] ?? 0; // referencia: lo de la última vez
    } else {
      final conocidos = _ultimos ?? (_maximos.isEmpty ? null : Map.of(_maximos));
      _meta = p.metaFija ?? metaProgresiva(p.def!, conocidos);
    }
    _empezarSerie();
  }

  void _empezarSerie() {
    // Primera serie de un ejercicio: 6 s para ver la demostración; si no, 2 s para prepararse
    final demo = _serie == 1 && _rep == 0 && _pasos[_iPaso].clase != _Clase.evaluacion;
    _tp = demo ? -6 : -2;
    _sost = _pasos[_iPaso].sostener.toDouble();
    _llego = false;
    _lado = 0;
    _zona = ZonaEjercicio.normal;
  }

  int get _segDescanso => _rehab ? (abreviado ? min(_descansoRutina, 5) : _descansoRutina) : (abreviado ? 3 : 10);

  void _contarRep() {
    final p = _pasos[_iPaso];
    _rep++;
    _tp = -0.8;
    _llego = false;
    _sost = p.sostener.toDouble();
    if (_rep < p.reps) return;

    if (_serie < p.series) {
      _serie++;
      _rep = 0;
      _descanso = _segDescanso.toDouble();
      _zona = ZonaEjercicio.normal;
      return;
    }

    // Ejercicio terminado
    _iPaso++;
    if (_iPaso >= _pasos.length) {
      _terminar(completa: true);
      return;
    }
    _empezarPaso();
    final siguiente = _pasos[_iPaso];
    if (p.clase != _Clase.evaluacion || siguiente.clase != _Clase.evaluacion) {
      _descanso = _segDescanso.toDouble();
    }
  }

  void _terminar({required bool completa}) {
    if (_rehab) {
      final r = ResultadoRehab(
        fecha: DateTime.now(),
        maximos: {for (final t in TipoEjercicio.values) t: _maximos[t] ?? 0},
        completa: completa,
      );
      final leido = ContratoBle.leerResultados(ContratoBle.escribirResultados(r));
      if (completa) _ultimos = leido.maximos;
      _resultados.add(leido);
    } else {
      _trabajo = 0; // pausa realizada: reinicia el tiempo de trabajo
    }
    _detener();
  }

  void _detener() {
    _activo = false;
    _descanso = 0;
    _calibrando = 0;
    _actual = null;
    _bytesActual = null;
  }

  // ---------------- Cada 100 ms ----------------

  void _tick() {
    _t += 0.1;
    _bateria = max(0.0, _bateria - 0.002);
    final antebrazo = 4 * sin(_t * 0.2); // el antebrazo casi quieto, como en un escritorio

    if (_activo) {
      _tickActividad(antebrazo);
      return;
    }

    if (_modo == ModoBrazalete.rehabilitacion) {
      // Esperando la rutina: mano en reposo
      _lectura(1.5 * sin(_t * 0.7), 1.0 * sin(_t * 0.5), EstadoPostura.verde, FaseBrazalete.menu, antebrazo);
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

    _lectura(flexion, desviacion, estado, FaseBrazalete.midiendo, antebrazo);
  }

  void _tickActividad(double antebrazo) {
    final temblor = 0.4 * sin(_t * 9);

    if (_calibrando > 0) {
      _calibrando -= 0.1;
      _lectura(temblor, temblor * 0.5, EstadoPostura.verde, FaseBrazalete.calibrando, antebrazo);
      return;
    }

    if (_descanso > 0) {
      _descanso -= 0.1;
      if (_descanso <= 0) {
        _descanso = 0;
        _empezarSerie();
      }
      _notificar();
      _lectura(temblor, temblor * 0.5, EstadoPostura.verde, FaseBrazalete.descanso, antebrazo);
      return;
    }

    final p = _pasos[_iPaso];
    _tp += 0.1;
    final ang = _movimientoPaciente(p);
    final l = LecturaEnVivo(
      flexion: ang.$1 + temblor,
      desviacion: ang.$2 + temblor * 0.5,
      estado: EstadoPostura.verde,
      fase: FaseBrazalete.ejercicio,
      antebrazo: antebrazo,
    );

    // Rango articular: el máximo alcanzado en las evaluaciones (línea base y final)
    if (_rehab && p.clase == _Clase.evaluacion) {
      for (final t in TipoEjercicio.values) {
        final v = t.desde(l);
        if (v > (_maximos[t] ?? 0)) _maximos[t] = v;
      }
    }

    if (_tp >= 0) _contar(p, l);

    final fase = !_activo
        ? (_rehab ? FaseBrazalete.menu : FaseBrazalete.midiendo)
        : (p.clase == _Clase.evaluacion
            ? FaseBrazalete.evaluacion
            : (_rehab ? FaseBrazalete.ejercicio : FaseBrazalete.pausaActiva));
    _notificar();
    _lectura(
      l.flexion,
      l.desviacion,
      _zona == ZonaEjercicio.riesgo ? EstadoPostura.rojo : EstadoPostura.verde,
      fase,
      antebrazo,
    );
  }

  // Lógica del firmware: decide zona, sostener y repeticiones a partir del ángulo
  void _contar(_Paso p, LecturaEnVivo l) {
    final a = p.movs.first.desde(l);
    switch (p.clase) {
      case _Clase.repeticion:
        if (p.riesgo != null && a > p.riesgo!) {
          _zona = ZonaEjercicio.riesgo;
        } else if (!_llego) {
          if (a >= _meta - 3) {
            _zona = ZonaEjercicio.enMeta;
            _sost -= 0.1;
            if (_sost <= 0) {
              _sost = 0;
              _marcarLlego();
            }
          } else {
            _zona = ZonaEjercicio.normal;
            _sost = p.sostener.toDouble(); // se soltó antes de tiempo: vuelve a empezar
          }
        } else {
          _zona = ZonaEjercicio.normal;
          if (a <= 8) _contarRep();
        }

      case _Clase.alterno:
        final b = p.movs.last.desde(l);
        final mayor = max(a, b);
        if (p.riesgo != null && mayor > p.riesgo!) {
          _zona = ZonaEjercicio.riesgo;
        } else {
          _zona = mayor >= _meta - 3 ? ZonaEjercicio.enMeta : ZonaEjercicio.normal;
        }
        if (a >= _meta - 3 && _lado != 1) {
          final contar = _lado == -1;
          _lado = 1;
          if (contar) _contarRep();
        } else if (b >= _meta - 3 && _lado != -1) {
          final contar = _lado == 1;
          _lado = -1;
          if (contar) _contarRep();
        }

      case _Clase.sostenido:
        if (_llego) {
          _zona = ZonaEjercicio.normal;
          if (a <= 8) _contarRep();
        } else if (p.riesgo != null && a > p.riesgo!) {
          _zona = ZonaEjercicio.riesgo; // se pasó: el tiempo se detiene
        } else if (a >= _meta - 1) {
          _zona = ZonaEjercicio.enMeta;
          _sost -= 0.1;
          if (_sost <= 0) {
            _sost = 0;
            _marcarLlego();
          }
        } else {
          _zona = ZonaEjercicio.normal;
        }

      case _Clase.neutro:
        if (l.flexion.abs() > (p.riesgo ?? 12)) {
          _zona = ZonaEjercicio.riesgo; // muñeca doblada: el tiempo se detiene
        } else {
          _zona = ZonaEjercicio.enMeta;
          _sost -= 0.1;
          if (_sost <= 0) _contarRep();
        }

      case _Clase.evaluacion:
        _zona = ZonaEjercicio.normal;
        _sost -= 0.1;
        if (_sost <= 0) _contarRep();
    }
  }

  void _marcarLlego() {
    _llego = true;
    _tLlego = _tp;
  }

  // ---------------- El "paciente" simulado ----------------

  static double _suave(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  // Sube a la meta, la sostiene hasta que el brazalete la da por buena y vuelve a 0°
  double _subirSostenerBajar(double objetivo, {double subir = 1.5, double bajar = 1.5}) {
    if (_tp < 0) return 0;
    if (!_llego) return _suave(_tp / subir) * objetivo;
    final d = _tp - _tLlego - 0.3;
    if (d < 0) return objetivo;
    return (1 - _suave(d / bajar)) * objetivo;
  }

  // Ángulo a lo largo de un movimiento → (flexión, desviación)
  static (double, double) _aAngulos(TipoEjercicio t, double v) => switch (t) {
        TipoEjercicio.flexion => (v, 0.0),
        TipoEjercicio.extension => (-v, 0.0),
        TipoEjercicio.radial => (0.0, v),
        TipoEjercicio.cubital => (0.0, -v),
      };

  (double, double) _movimientoPaciente(_Paso p) {
    final mov = p.movs.first;
    switch (p.clase) {
      case _Clase.repeticion:
        return _aAngulos(mov, _subirSostenerBajar(_meta + 2));

      case _Clase.alterno:
        if (_tp < 0) return (0, 0);
        final periodo = p.codigo == IdEjercicio.p1Bombeo.index ? 2.0 : 3.0;
        var amplitud = _meta + 2;
        // Una vez por ejercicio se pasa del límite, para que se vea la alerta
        if (_serie == 1 && _rep == 2 && p.riesgo != null) amplitud = p.riesgo! + 4;
        final v = amplitud * sin(2 * pi * _tp / periodo) * _suave(_tp / 0.6);
        return _aAngulos(mov, v);

      case _Clase.sostenido:
        // La primera vez se pasa un poco y luego corrige
        final exceso = (_serie == 1 && _rep == 0 && p.riesgo != null)
            ? (p.riesgo! + 3 - _meta) * (1 - _suave((_tp - 3.5) / 1.5))
            : 0.0;
        return _aAngulos(mov, _subirSostenerBajar(_meta + 2.5 + (_llego ? 0 : exceso), subir: 2));

      case _Clase.neutro:
        if (_tp < 0) return (0, 0);
        var v = 3 * sin(_tp * 1.3);
        if (_tp > 4 && _tp < 6.5) v += 14 * sin(pi * (_tp - 4) / 2.5); // se le dobla la muñeca un momento
        return (v, 0);

      case _Clase.evaluacion:
        if (_tp < 0) return (0, 0);
        final cap = _capacidad[mov] ?? 20;
        final dur = p.sostener.toDouble();
        final v = _tp < dur - 1.5 ? _suave(_tp / 2) * cap : (1 - _suave((_tp - (dur - 1.5)) / 1.5)) * cap;
        return _aAngulos(mov, v);
    }
  }

  // ---------------- Envío por el contrato ----------------

  void _notificar() {
    if (!_activo) return;
    final p = _pasos[_iPaso];
    final signo = switch (p.movs.first) {
      TipoEjercicio.flexion || TipoEjercicio.radial => 1.0,
      TipoEjercicio.extension || TipoEjercicio.cubital => -1.0,
    };
    final e = EjercicioEnCurso(
      codigo: p.codigo,
      objetivo: signo * _meta,
      repeticion: _rep,
      repeticionesTotal: p.reps,
      serie: _serie,
      seriesTotal: p.series,
      descanso: _descanso.ceil(),
      sostener: _sost.ceil(),
      zona: _zona,
    );
    final b = ContratoBle.escribirEjercicio(e);
    final antes = _bytesActual;
    if (antes != null && antes.length == b.length) {
      var igual = true;
      for (var i = 0; i < b.length; i++) {
        if (antes[i] != b[i]) {
          igual = false;
          break;
        }
      }
      if (igual) return; // el brazalete solo notifica cuando algo cambia
    }
    _bytesActual = b;
    _actual = ContratoBle.leerEjercicio(b);
    _ejercicio.add(_actual!);
  }

  void _lectura(double flexion, double desviacion, EstadoPostura estado, FaseBrazalete fase, double antebrazo) {
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

  // Posturas reales en un ciclo de 20 s: (segundo, flexión, desviación)
  static const _poses = [
    (0.0, 0.0, 0.0), // descanso
    (3.0, 0.0, 0.0),
    (4.2, -12.0, -8.0), // escribiendo en teclado
    (7.5, -12.0, -8.0),
    (8.5, -8.0, -18.0), // usando el mouse (desviación cubital)
    (10.5, -8.0, -18.0),
    (11.5, 5.0, 12.0), // alcanza algo (desviación radial)
    (12.5, 5.0, 12.0),
    (13.5, 26.0, -5.0), // muñeca en flexión sostenida: mala postura
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
