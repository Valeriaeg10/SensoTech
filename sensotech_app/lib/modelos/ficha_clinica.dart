import 'datos_brazalete.dart';

// Resultado de una prueba clínica (Phalen, Tinel, Durkan)
enum ResultadoPrueba { sinRealizar, negativa, positiva }

extension TextoPrueba on ResultadoPrueba {
  String get texto => switch (this) {
        ResultadoPrueba.sinRealizar => 'No realizada',
        ResultadoPrueba.negativa => 'Negativa',
        ResultadoPrueba.positiva => 'Positiva',
      };
}

// Ficha clínica del paciente: identificación (Res. 1995 de 1999, art. 9) y valoración inicial
class FichaClinica {
  final String pacienteId;
  // Identificación
  final String tipoDocumento; // CC, TI, CE, PA
  final String numeroDocumento;
  final DateTime? fechaNacimiento;
  final String sexo; // Femenino, Masculino, Intersexual
  final String estadoCivil;
  final String ocupacion;
  final String telefono;
  final String direccion;
  final String eps; // aseguradora
  final String acompanante; // nombre del acompañante o responsable (Res. 1995, según el caso)
  final String acompananteTelefono;
  final String acompananteParentesco;
  final String manoDominante; // Derecha / Izquierda
  final String manoAfectada; // Derecha / Izquierda / Bilateral
  final String manoBrazalete; // si es bilateral: en cuál mano se pone el brazalete
  // Valoración inicial
  final DateTime? fechaValoracion;
  final String motivoConsulta;
  final String diagnostico; // texto
  final String codigoCie10; // p. ej. G56.0
  final String antecedentes;
  final int? dolorInicial; // EVA 0–10
  final Map<TipoEjercicio, double> goniometria; // grados
  final ResultadoPrueba phalen;
  final ResultadoPrueba tinel;
  final ResultadoPrueba durkan;
  final double? bctq; // Boston Carpal Tunnel Questionnaire, puntaje de severidad (1–5)
  final String objetivos;

  const FichaClinica({
    required this.pacienteId,
    this.tipoDocumento = 'CC',
    this.numeroDocumento = '',
    this.fechaNacimiento,
    this.sexo = '',
    this.estadoCivil = '',
    this.ocupacion = '',
    this.telefono = '',
    this.direccion = '',
    this.eps = '',
    this.acompanante = '',
    this.acompananteTelefono = '',
    this.acompananteParentesco = '',
    this.manoDominante = 'Derecha',
    this.manoAfectada = 'Derecha',
    this.manoBrazalete = 'Derecha',
    this.fechaValoracion,
    this.motivoConsulta = '',
    this.diagnostico = 'Síndrome del túnel carpiano',
    this.codigoCie10 = 'G56.0',
    this.antecedentes = '',
    this.dolorInicial,
    this.goniometria = const {},
    this.phalen = ResultadoPrueba.sinRealizar,
    this.tinel = ResultadoPrueba.sinRealizar,
    this.durkan = ResultadoPrueba.sinRealizar,
    this.bctq,
    this.objetivos = '',
  });

  // Acompañante en una sola línea: nombre (parentesco) · teléfono
  String get textoAcompanante {
    if (acompanante.trim().isEmpty) return '';
    final p = acompananteParentesco.trim().isEmpty ? '' : ' ($acompananteParentesco)';
    final t = acompananteTelefono.trim().isEmpty ? '' : ' · $acompananteTelefono';
    return '$acompanante$p$t';
  }

  // Mano donde el paciente usa el brazalete (la define el fisio)
  bool get brazaleteIzquierda =>
      manoAfectada == 'Izquierda' || (manoAfectada == 'Bilateral' && manoBrazalete == 'Izquierda');

  int? get edad {
    final n = fechaNacimiento;
    if (n == null) return null;
    final hoy = DateTime.now();
    var e = hoy.year - n.year;
    if (hoy.month < n.month || (hoy.month == n.month && hoy.day < n.day)) e--;
    return e;
  }

  Map<String, dynamic> aMapa() => {
        'pacienteId': pacienteId,
        'tipoDocumento': tipoDocumento,
        'numeroDocumento': numeroDocumento,
        'fechaNacimiento': fechaNacimiento?.toIso8601String(),
        'sexo': sexo,
        'estadoCivil': estadoCivil,
        'ocupacion': ocupacion,
        'telefono': telefono,
        'direccion': direccion,
        'eps': eps,
        'acompanante': acompanante,
        'acompananteTelefono': acompananteTelefono,
        'acompananteParentesco': acompananteParentesco,
        'manoDominante': manoDominante,
        'manoAfectada': manoAfectada,
        'manoBrazalete': manoBrazalete,
        'fechaValoracion': fechaValoracion?.toIso8601String(),
        'motivoConsulta': motivoConsulta,
        'diagnostico': diagnostico,
        'codigoCie10': codigoCie10,
        'antecedentes': antecedentes,
        'dolorInicial': dolorInicial,
        'goniometria': {for (final e in goniometria.entries) e.key.name: e.value},
        'phalen': phalen.index,
        'tinel': tinel.index,
        'durkan': durkan.index,
        'bctq': bctq,
        'objetivos': objetivos,
      };

  factory FichaClinica.desdeMapa(Map<String, dynamic> m) {
    DateTime? fecha(String k) => m[k] == null ? null : DateTime.parse(m[k] as String);
    final g = Map<String, dynamic>.from((m['goniometria'] as Map?) ?? {});
    return FichaClinica(
      pacienteId: m['pacienteId'] as String,
      tipoDocumento: (m['tipoDocumento'] as String?) ?? 'CC',
      numeroDocumento: (m['numeroDocumento'] as String?) ?? '',
      fechaNacimiento: fecha('fechaNacimiento'),
      sexo: (m['sexo'] as String?) ?? '',
      estadoCivil: (m['estadoCivil'] as String?) ?? '',
      ocupacion: (m['ocupacion'] as String?) ?? '',
      telefono: (m['telefono'] as String?) ?? '',
      direccion: (m['direccion'] as String?) ?? '',
      eps: (m['eps'] as String?) ?? '',
      acompanante: (m['acompanante'] as String?) ?? '',
      acompananteTelefono: (m['acompananteTelefono'] as String?) ?? '',
      acompananteParentesco: (m['acompananteParentesco'] as String?) ?? '',
      manoDominante: (m['manoDominante'] as String?) ?? 'Derecha',
      manoAfectada: (m['manoAfectada'] as String?) ?? 'Derecha',
      manoBrazalete: (m['manoBrazalete'] as String?) ?? 'Derecha',
      fechaValoracion: fecha('fechaValoracion'),
      motivoConsulta: (m['motivoConsulta'] as String?) ?? '',
      diagnostico: (m['diagnostico'] as String?) ?? '',
      codigoCie10: (m['codigoCie10'] as String?) ?? '',
      antecedentes: (m['antecedentes'] as String?) ?? '',
      dolorInicial: m['dolorInicial'] as int?,
      goniometria: {
        for (final t in TipoEjercicio.values)
          if (g[t.name] != null) t: (g[t.name] as num).toDouble(),
      },
      phalen: ResultadoPrueba.values[(m['phalen'] as int?) ?? 0],
      tinel: ResultadoPrueba.values[(m['tinel'] as int?) ?? 0],
      durkan: ResultadoPrueba.values[(m['durkan'] as int?) ?? 0],
      bctq: (m['bctq'] as num?)?.toDouble(),
      objetivos: (m['objetivos'] as String?) ?? '',
    );
  }
}

// Nota de evolución escrita por el fisio (fecha, hora y autor, Res. 1995 art. 5)
class NotaEvolucion {
  final String pacienteId;
  final DateTime fecha;
  final String texto;
  final String autor; // nombre del fisio
  final String tarjeta; // tarjeta profesional

  const NotaEvolucion({
    required this.pacienteId,
    required this.fecha,
    required this.texto,
    required this.autor,
    required this.tarjeta,
  });

  Map<String, dynamic> aMapa() => {
        'pacienteId': pacienteId,
        'fecha': fecha.toIso8601String(),
        'texto': texto,
        'autor': autor,
        'tarjeta': tarjeta,
      };

  factory NotaEvolucion.desdeMapa(Map<String, dynamic> m) => NotaEvolucion(
        pacienteId: m['pacienteId'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        texto: m['texto'] as String,
        autor: m['autor'] as String,
        tarjeta: (m['tarjeta'] as String?) ?? '',
      );
}

// Fecha y hora en formato dd/mm/aaaa hh:mm
String fechaHora(DateTime f) {
  String d(int n) => n.toString().padLeft(2, '0');
  return '${d(f.day)}/${d(f.month)}/${f.year} ${d(f.hour)}:${d(f.minute)}';
}

String soloFecha(DateTime f) {
  String d(int n) => n.toString().padLeft(2, '0');
  return '${d(f.day)}/${d(f.month)}/${f.year}';
}
