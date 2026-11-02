import 'rutina.dart';

// Programación de sesiones que el fisio le asigna al paciente
// Ejemplo: martes y jueves a las 11:00, 12 sesiones desde el 4 de noviembre
class Agenda {
  final List<int> dias; // 1 = lunes … 7 = domingo
  final int hora;
  final int minuto;
  final DateTime inicio; // fecha desde la que se cuentan las sesiones
  final int totalSesiones;
  final Map<String, DateTime?> cambios; // sesión original → nueva fecha (null = cancelada)
  final DateTime actualizada;

  const Agenda({
    required this.dias,
    required this.hora,
    required this.minuto,
    required this.inicio,
    required this.totalSesiones,
    this.cambios = const {},
    required this.actualizada,
  });

  static const nombresDias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const letrasDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String get textoHora => '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  // "martes y jueves a las 11:00"
  String get textoDias {
    final n = ([...dias]..sort()).map((d) => nombresDias[d - 1]).toList();
    final lista = n.length == 1 ? n.first : '${n.sublist(0, n.length - 1).join(', ')} y ${n.last}';
    return '$lista a las $textoHora';
  }

  static String clave(DateTime f) => f.toIso8601String();

  // Fechas originales según los días elegidos (sin cambios)
  List<DateTime> _originales(int cantidad) {
    final r = <DateTime>[];
    var d = DateTime(inicio.year, inicio.month, inicio.day);
    var vueltas = 0;
    while (r.length < cantidad && dias.isNotEmpty && vueltas < 3660) {
      if (dias.contains(d.weekday)) r.add(DateTime(d.year, d.month, d.day, hora, minuto));
      d = DateTime(d.year, d.month, d.day + 1);
      vueltas++;
    }
    return r;
  }

  // Sesiones programadas, ya con los cambios. Una cancelada se reemplaza por otra al final.
  List<SesionProgramada> sesiones() {
    final canceladas = cambios.values.where((v) => v == null).length;
    final lista = <SesionProgramada>[];
    for (final o in _originales(totalSesiones + canceladas)) {
      final k = clave(o);
      if (cambios.containsKey(k)) {
        final nueva = cambios[k];
        if (nueva != null) lista.add(SesionProgramada(original: o, fecha: nueva, reprogramada: true));
      } else {
        lista.add(SesionProgramada(original: o, fecha: o));
      }
    }
    lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista.take(totalSesiones).toList();
  }

  Agenda conCambio(DateTime original, DateTime? nueva) => Agenda(
        dias: dias,
        hora: hora,
        minuto: minuto,
        inicio: inicio,
        totalSesiones: totalSesiones,
        cambios: {...cambios, clave(original): nueva},
        actualizada: DateTime.now(),
      );

  Map<String, dynamic> aMapa() => {
        'dias': dias,
        'hora': hora,
        'minuto': minuto,
        'inicio': inicio.toIso8601String(),
        'total': totalSesiones,
        'cambios': cambios.map((k, v) => MapEntry(k, v?.toIso8601String())),
        'actualizada': actualizada.toIso8601String(),
      };

  factory Agenda.desdeMapa(Map<String, dynamic> m) => Agenda(
        dias: (m['dias'] as List).map((e) => e as int).toList(),
        hora: m['hora'] as int,
        minuto: m['minuto'] as int,
        inicio: DateTime.parse(m['inicio'] as String),
        totalSesiones: m['total'] as int,
        cambios: Map<String, dynamic>.from((m['cambios'] as Map?) ?? {})
            .map((k, v) => MapEntry(k, v == null ? null : DateTime.parse(v as String))),
        actualizada: DateTime.parse(m['actualizada'] as String),
      );
}

enum EstadoProgramada { realizada, perdida, hoy, pendiente }

class SesionProgramada {
  final DateTime original;
  final DateTime fecha;
  final bool reprogramada;

  const SesionProgramada({required this.original, required this.fecha, this.reprogramada = false});
}

bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// Cruza lo programado con las sesiones hechas (cuenta la sesión hecha ese mismo día)
class Cumplimiento {
  final List<(SesionProgramada, EstadoProgramada)> lista;

  Cumplimiento(Agenda agenda, List<SesionRehab> hechas, {DateTime? ahora}) : lista = [] {
    final hoy = ahora ?? DateTime.now();
    final usadas = <SesionRehab>{};
    for (final p in agenda.sesiones()) {
      SesionRehab? hecha;
      for (final s in hechas) {
        if (!usadas.contains(s) && mismoDia(s.fecha, p.fecha)) {
          hecha = s;
          break;
        }
      }
      final EstadoProgramada e;
      if (hecha != null) {
        usadas.add(hecha);
        e = EstadoProgramada.realizada;
      } else if (mismoDia(p.fecha, hoy)) {
        e = EstadoProgramada.hoy;
      } else if (p.fecha.isBefore(hoy)) {
        e = EstadoProgramada.perdida;
      } else {
        e = EstadoProgramada.pendiente;
      }
      lista.add((p, e));
    }
  }

  int contar(EstadoProgramada e) => lista.where((x) => x.$2 == e).length;
  int get realizadas => contar(EstadoProgramada.realizada);
  int get perdidas => contar(EstadoProgramada.perdida);
  int get total => lista.length;
  int get faltan => total - realizadas - perdidas;

  // Próxima sesión por hacer (hoy o después)
  SesionProgramada? get proxima {
    for (final x in lista) {
      if (x.$2 == EstadoProgramada.hoy || x.$2 == EstadoProgramada.pendiente) return x.$1;
    }
    return null;
  }

  // Número de la próxima sesión dentro del plan (1, 2, 3…)
  int? get numeroProxima {
    for (var i = 0; i < lista.length; i++) {
      if (lista[i].$2 == EstadoProgramada.hoy || lista[i].$2 == EstadoProgramada.pendiente) return i + 1;
    }
    return null;
  }

  // Perdidas en las últimas 3 sesiones que ya pasaron
  int get perdidasRecientes {
    final pasadas = lista
        .where((x) => x.$2 == EstadoProgramada.realizada || x.$2 == EstadoProgramada.perdida)
        .toList();
    final ultimas = pasadas.length > 3 ? pasadas.sublist(pasadas.length - 3) : pasadas;
    return ultimas.where((x) => x.$2 == EstadoProgramada.perdida).length;
  }
}

// "mar 4 nov · 11:00"
String fechaSesion(DateTime f) {
  const d = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const m = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${d[f.weekday - 1]} ${f.day} ${m[f.month - 1]} · '
      '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
}
