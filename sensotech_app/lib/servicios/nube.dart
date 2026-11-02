import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/agenda.dart';
import '../modelos/cuenta.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';
import 'nube_firebase.dart';

// Error con mensaje para mostrar en pantalla
class ErrorCuenta implements Exception {
  final String mensaje;
  ErrorCuenta(this.mensaje);
  @override
  String toString() => mensaje;
}

// Lo que la app necesita del servidor. Hoy: NubeLocal. Después: NubeFirebase.
abstract class Nube {
  // Cuentas
  Future<Cuenta?> sesionActual();
  Future<Cuenta> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required Rol rol,
    String? tarjetaProfesional,
  });
  Future<Cuenta> iniciarSesion(String correo, String contrasena);
  Future<void> cerrarSesion();
  Future<Cuenta> cambiarClave(Cuenta c, String nueva);
  Future<Cuenta?> cuenta(String id);

  // El fisio crea la cuenta del paciente (sin cerrar su propia sesión)
  Future<Cuenta> crearPaciente({
    required Cuenta fisio,
    required String nombre,
    required String correo,
    required String claveTemporal,
    required FichaClinica ficha,
  });
  Future<List<Cuenta>> pacientesDe(String fisioId);

  // Historia
  Future<FichaClinica?> ficha(String pacienteId);
  Future<void> guardarFicha(FichaClinica f);
  Future<List<NotaEvolucion>> notas(String pacienteId);
  Future<void> agregarNota(NotaEvolucion n);

  // Rutina y sesiones de rehabilitación
  Future<Rutina?> rutina(String pacienteId);
  Future<void> guardarRutina(String pacienteId, Rutina rutina);
  Future<List<SesionRehab>> sesionesRehab(String pacienteId);
  Future<void> guardarRehab(SesionRehab s);

  // Programación de sesiones (días y hora)
  Future<Agenda?> agenda(String pacienteId);
  Future<void> guardarAgenda(String pacienteId, Agenda agenda);

  // Solo para la demostración: pacientes de ejemplo (sin usuario para entrar)
  String idNuevo();
  Future<void> agregarCuentasDemo(List<Cuenta> nuevas);
}

// Nube simulada: guarda todo en el celular con la misma estructura que tendrá Firebase
class NubeLocal implements Nube {
  static const _kCuentas = 'nube_cuentas';
  static const _kClaves = 'nube_claves';
  static const _kSesion = 'nube_sesion';

  final _azar = Random();

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  // Contraseña guardada como huella (sha256), nunca en texto plano
  String _huella(String correo, String contrasena) =>
      sha256.convert(utf8.encode('${correo.toLowerCase()}::$contrasena')).toString();

  String _nuevoId() => '${DateTime.now().millisecondsSinceEpoch}${_azar.nextInt(9999)}';
  @override
  String idNuevo() => _nuevoId();

  Future<Map<String, Cuenta>> _cuentas() async {
    final texto = (await _p).getString(_kCuentas);
    if (texto == null) return {};
    final m = jsonDecode(texto) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, Cuenta.desdeMapa(Map<String, dynamic>.from(v as Map))));
  }

  Future<void> _guardarCuentas(Map<String, Cuenta> c) async {
    await (await _p).setString(_kCuentas, jsonEncode(c.map((k, v) => MapEntry(k, v.aMapa()))));
  }

  Future<void> _guardarClave(String id, String correo, String clave) async {
    final p = await _p;
    final texto = p.getString(_kClaves);
    final claves = texto == null ? <String, dynamic>{} : jsonDecode(texto) as Map<String, dynamic>;
    claves[id] = _huella(correo, clave);
    await p.setString(_kClaves, jsonEncode(claves));
  }

  Future<Cuenta> _nuevaCuenta(Cuenta c, String clave) async {
    final cuentas = await _cuentas();
    if (cuentas.values.any((x) => x.correo == c.correo)) {
      throw ErrorCuenta('Ya existe una cuenta con ese correo');
    }
    cuentas[c.id] = c;
    await _guardarCuentas(cuentas);
    await _guardarClave(c.id, c.correo, clave);
    return c;
  }

  @override
  Future<Cuenta?> sesionActual() async {
    final id = (await _p).getString(_kSesion);
    return id == null ? null : cuenta(id);
  }

  @override
  Future<Cuenta> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required Rol rol,
    String? tarjetaProfesional,
  }) async {
    final nueva = await _nuevaCuenta(
      Cuenta(
        id: _nuevoId(),
        nombre: nombre.trim(),
        correo: correo.trim().toLowerCase(),
        rol: rol,
        creado: DateTime.now(),
        tarjetaProfesional: tarjetaProfesional?.trim(),
      ),
      contrasena,
    );
    await (await _p).setString(_kSesion, nueva.id);
    return nueva;
  }

  @override
  Future<Cuenta> iniciarSesion(String correo, String contrasena) async {
    final c = correo.trim().toLowerCase();
    Cuenta? encontrada;
    for (final x in (await _cuentas()).values) {
      if (x.correo == c) encontrada = x;
    }
    final texto = (await _p).getString(_kClaves);
    final claves = texto == null ? <String, dynamic>{} : jsonDecode(texto) as Map<String, dynamic>;
    // Mismo mensaje para correo o contraseña incorrectos (no revela cuál falló)
    if (encontrada == null || claves[encontrada.id] != _huella(c, contrasena)) {
      throw ErrorCuenta('Correo o contraseña incorrectos');
    }
    await (await _p).setString(_kSesion, encontrada.id);
    return encontrada;
  }

  @override
  Future<void> cerrarSesion() async {
    await (await _p).remove(_kSesion);
  }

  @override
  Future<Cuenta> cambiarClave(Cuenta c, String nueva) async {
    await _guardarClave(c.id, c.correo, nueva);
    final cuentas = await _cuentas();
    final actualizada = c.copia(debeCambiarClave: false);
    cuentas[c.id] = actualizada;
    await _guardarCuentas(cuentas);
    return actualizada;
  }

  @override
  Future<Cuenta?> cuenta(String id) async => (await _cuentas())[id];

  @override
  Future<Cuenta> crearPaciente({
    required Cuenta fisio,
    required String nombre,
    required String correo,
    required String claveTemporal,
    required FichaClinica ficha,
  }) async {
    final id = _nuevoId();
    final p = await _nuevaCuenta(
      Cuenta(
        id: id,
        nombre: nombre.trim(),
        correo: correo.trim().toLowerCase(),
        rol: Rol.paciente,
        creado: DateTime.now(),
        fisioId: fisio.id,
        debeCambiarClave: true,
      ),
      claveTemporal,
    );
    await guardarFicha(FichaClinica.desdeMapa({...ficha.aMapa(), 'pacienteId': id}));
    return p;
  }

  @override
  Future<List<Cuenta>> pacientesDe(String fisioId) async {
    final l = (await _cuentas()).values.where((x) => x.fisioId == fisioId).toList();
    l.sort((a, b) => a.nombre.compareTo(b.nombre));
    return l;
  }

  @override
  Future<FichaClinica?> ficha(String pacienteId) async {
    final t = (await _p).getString('ficha_$pacienteId');
    return t == null ? null : FichaClinica.desdeMapa(jsonDecode(t) as Map<String, dynamic>);
  }

  @override
  Future<void> guardarFicha(FichaClinica f) async {
    await (await _p).setString('ficha_${f.pacienteId}', jsonEncode(f.aMapa()));
  }

  @override
  Future<List<NotaEvolucion>> notas(String pacienteId) async {
    final l = (await _p).getStringList('notas_$pacienteId') ?? [];
    final n = l.map((t) => NotaEvolucion.desdeMapa(jsonDecode(t) as Map<String, dynamic>)).toList();
    n.sort((a, b) => b.fecha.compareTo(a.fecha)); // más reciente primero
    return n;
  }

  @override
  Future<void> agregarNota(NotaEvolucion n) async {
    final p = await _p;
    final l = p.getStringList('notas_${n.pacienteId}') ?? [];
    l.add(jsonEncode(n.aMapa()));
    await p.setStringList('notas_${n.pacienteId}', l);
  }

  @override
  Future<Rutina?> rutina(String pacienteId) async {
    final t = (await _p).getString('rutina_$pacienteId');
    if (t == null) return null;
    try {
      return Rutina.desdeMapa(jsonDecode(t) as Map<String, dynamic>);
    } catch (_) {
      return null; // rutina con el formato viejo: se usa la predefinida
    }
  }

  @override
  Future<void> guardarRutina(String pacienteId, Rutina rutina) async {
    await (await _p).setString('rutina_$pacienteId', jsonEncode(rutina.aMapa()));
  }

  @override
  Future<List<SesionRehab>> sesionesRehab(String pacienteId) async {
    final l = (await _p).getStringList('rehab_$pacienteId') ?? [];
    final s = <SesionRehab>[];
    for (final t in l) {
      try {
        s.add(SesionRehab.desdeMapa(jsonDecode(t) as Map<String, dynamic>));
      } catch (_) {} // se ignora un registro dañado
    }
    s.sort((a, b) => a.fecha.compareTo(b.fecha)); // de la más vieja a la más reciente
    return s;
  }

  @override
  Future<void> guardarRehab(SesionRehab s) async {
    final p = await _p;
    final l = p.getStringList('rehab_${s.perfilId}') ?? [];
    l.add(jsonEncode(s.aMapa()));
    await p.setStringList('rehab_${s.perfilId}', l);
  }

  @override
  Future<Agenda?> agenda(String pacienteId) async {
    final t = (await _p).getString('agenda_$pacienteId');
    if (t == null) return null;
    try {
      return Agenda.desdeMapa(jsonDecode(t) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardarAgenda(String pacienteId, Agenda agenda) async {
    await (await _p).setString('agenda_$pacienteId', jsonEncode(agenda.aMapa()));
  }

  // Solo para la demostración: cuentas de ejemplo ya vinculadas al fisio
  @override
  Future<void> agregarCuentasDemo(List<Cuenta> nuevas) async {
    final cuentas = await _cuentas();
    for (final c in nuevas) {
      cuentas[c.id] = c;
    }
    await _guardarCuentas(cuentas);
  }
}

// Una sola nube para toda la app: Firebase (NubeLocal queda para pruebas sin internet)
final Nube nube = NubeFirebase();

// Contraseña temporal fácil de dictar: 3 letras + 3 números
String claveTemporal() {
  final r = Random();
  const letras = 'ABCDEFGHJKMNPQRSTUVWXYZ';
  return List.generate(3, (_) => letras[r.nextInt(letras.length)]).join() +
      List.generate(3, (_) => r.nextInt(10)).join();
}
