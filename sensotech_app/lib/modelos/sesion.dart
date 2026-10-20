import 'perfil.dart';

// Resumen de una jornada de prevención (como la característica 0005)
class SesionPrevencion {
  final String id;
  final String perfilId;
  final DateTime fecha;
  final TipoTrabajo tipo;
  final int segundosTrabajo;
  final int segundosFuera;
  final int alertas;
  final bool completa; // false = cancelada / incompleta

  SesionPrevencion({
    required this.id,
    required this.perfilId,
    required this.fecha,
    required this.tipo,
    required this.segundosTrabajo,
    required this.segundosFuera,
    required this.alertas,
    required this.completa,
  });

  // % del tiempo con la muñeca fuera de rango
  int get porcentajeFuera =>
      segundosTrabajo == 0 ? 0 : (segundosFuera * 100 / segundosTrabajo).round();

  String get fechaTexto {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}  ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Map<String, dynamic> aMapa() => {
        'id': id,
        'perfilId': perfilId,
        'fecha': fecha.toIso8601String(),
        'tipo': tipo.index,
        'trabajo': segundosTrabajo,
        'fuera': segundosFuera,
        'alertas': alertas,
        'completa': completa,
      };

  factory SesionPrevencion.desdeMapa(Map<String, dynamic> m) => SesionPrevencion(
        id: m['id'] as String,
        perfilId: m['perfilId'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        tipo: TipoTrabajo.values[m['tipo'] as int],
        segundosTrabajo: m['trabajo'] as int,
        segundosFuera: m['fuera'] as int,
        alertas: m['alertas'] as int,
        completa: m['completa'] as bool,
      );
}

// Formato de tiempo: 1 h 05 min, o 03:20 si es menos de una hora
String formatoDuracion(int segundos) {
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  final s = segundos % 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
