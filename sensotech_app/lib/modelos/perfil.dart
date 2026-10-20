// Tipo de trabajo del usuario (define la pausa activa)
enum TipoTrabajo { administrativo, repetitivo }

// Perfil guardado en el celular
class Perfil {
  final String id;
  final String nombre;
  final TipoTrabajo tipoTrabajo;
  final DateTime creado;

  Perfil({
    required this.id,
    required this.nombre,
    required this.tipoTrabajo,
    required this.creado,
  });

  // Texto para mostrar
  String get tipoTexto =>
      tipoTrabajo == TipoTrabajo.administrativo ? 'Administrativo' : 'Repetitivo';

  // Minutos entre pausas activas (hoja 2)
  int get minutosPausa => tipoTrabajo == TipoTrabajo.administrativo ? 60 : 45;

  // Perfil -> mapa (para guardar)
  Map<String, dynamic> aMapa() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipoTrabajo.index,
        'creado': creado.toIso8601String(),
      };

  // Mapa -> perfil (al leer)
  factory Perfil.desdeMapa(Map<String, dynamic> m) => Perfil(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        tipoTrabajo: TipoTrabajo.values[m['tipo'] as int],
        creado: DateTime.parse(m['creado'] as String),
      );
}
