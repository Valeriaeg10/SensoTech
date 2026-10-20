import 'datos_brazalete.dart';

// Tipo de trabajo (solo para el modo prevención)
enum TipoTrabajo { administrativo, repetitivo }

extension TextoTipoTrabajo on TipoTrabajo {
  String get texto => this == TipoTrabajo.administrativo ? 'Administrativo' : 'Repetitivo';

  // Minutos entre pausas activas (hoja 2)
  int get minutosPausa => this == TipoTrabajo.administrativo ? 60 : 45;
}

// Perfil guardado en el celular
class Perfil {
  final String id;
  final String nombre;
  final DateTime creado;
  final TipoTrabajo? ultimoTipo; // se recuerda para la próxima jornada
  final ModoBrazalete? ultimoModo; // al conectar se entra directo a este modo

  Perfil({
    required this.id,
    required this.nombre,
    required this.creado,
    this.ultimoTipo,
    this.ultimoModo,
  });

  // Copia con el modo y tipo de trabajo actualizados
  Perfil conModo(ModoBrazalete modo, {TipoTrabajo? tipo}) => Perfil(
        id: id,
        nombre: nombre,
        creado: creado,
        ultimoModo: modo,
        ultimoTipo: tipo ?? ultimoTipo,
      );

  String get fechaTexto =>
      '${creado.day.toString().padLeft(2, '0')}/${creado.month.toString().padLeft(2, '0')}/${creado.year}';

  // Perfil -> mapa (para guardar)
  Map<String, dynamic> aMapa() => {
        'id': id,
        'nombre': nombre,
        'creado': creado.toIso8601String(),
        'tipo': ultimoTipo?.index,
        'modo': ultimoModo?.index,
      };

  // Mapa -> perfil (al leer)
  factory Perfil.desdeMapa(Map<String, dynamic> m) {
    final tipo = m['tipo'] as int?;
    final modo = m['modo'] as int?;
    return Perfil(
      id: m['id'] as String,
      nombre: m['nombre'] as String,
      creado: DateTime.parse(m['creado'] as String),
      ultimoTipo: tipo == null ? null : TipoTrabajo.values[tipo],
      // Perfiles viejos con tipo pero sin modo: venían de prevención
      ultimoModo: modo != null
          ? ModoBrazalete.values[modo]
          : (tipo != null ? ModoBrazalete.prevencion : null),
    );
  }
}
