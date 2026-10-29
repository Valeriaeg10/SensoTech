// Rol de la cuenta
enum Rol { paciente, fisioterapeuta }

extension TextoRol on Rol {
  String get texto => this == Rol.paciente ? 'Paciente' : 'Fisioterapeuta';
}

// Cuenta de usuario (en Firebase será el documento /usuarios/{id})
class Cuenta {
  final String id;
  final String nombre;
  final String correo;
  final Rol rol;
  final DateTime creado;
  final String? fisioId; // paciente: fisio que lo agregó
  final String? tarjetaProfesional; // fisio: número de tarjeta profesional
  final bool debeCambiarClave; // paciente creado por el fisio con clave temporal
  final bool demo; // creado con datos de demostración

  Cuenta({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.creado,
    this.fisioId,
    this.tarjetaProfesional,
    this.debeCambiarClave = false,
    this.demo = false,
  });

  bool get esFisio => rol == Rol.fisioterapeuta;

  // Paciente agregado por un fisio: solo rehabilitación. Registrado por su cuenta: solo prevención.
  bool get esRehabilitacion => rol == Rol.paciente && fisioId != null;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    final a = partes.isNotEmpty && partes[0].isNotEmpty ? partes[0][0] : '?';
    final b = partes.length > 1 && partes[1].isNotEmpty ? partes[1][0] : '';
    return (a + b).toUpperCase();
  }

  Cuenta copia({String? nombre, bool? debeCambiarClave}) => Cuenta(
        id: id,
        nombre: nombre ?? this.nombre,
        correo: correo,
        rol: rol,
        creado: creado,
        fisioId: fisioId,
        tarjetaProfesional: tarjetaProfesional,
        debeCambiarClave: debeCambiarClave ?? this.debeCambiarClave,
        demo: demo,
      );

  Map<String, dynamic> aMapa() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
        'rol': rol.index,
        'creado': creado.toIso8601String(),
        'fisioId': fisioId,
        'tarjeta': tarjetaProfesional,
        'cambiarClave': debeCambiarClave,
        'demo': demo,
      };

  factory Cuenta.desdeMapa(Map<String, dynamic> m) => Cuenta(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        correo: m['correo'] as String,
        rol: Rol.values[m['rol'] as int],
        creado: DateTime.parse(m['creado'] as String),
        fisioId: m['fisioId'] as String?,
        tarjetaProfesional: m['tarjeta'] as String?,
        debeCambiarClave: (m['cambiarClave'] as bool?) ?? false,
        demo: (m['demo'] as bool?) ?? false,
      );
}
