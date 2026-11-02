import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../modelos/agenda.dart';
import '../modelos/cuenta.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';
import 'nube.dart';

// Nube real en Firebase
// usuarios/{uid}                      cuenta (fisio o paciente)
// pacientes/{id}/datos/ficha|rutina|agenda
// pacientes/{id}/notas/{auto}         notas de evolución
// pacientes/{id}/sesiones/{auto}      sesiones de rehabilitación
// Prevención no se sube: es privada y queda en el celular.
class NubeFirebase implements Nube {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios => _db.collection('usuarios');
  DocumentReference<Map<String, dynamic>> _dato(String pacienteId, String nombre) =>
      _db.collection('pacientes').doc(pacienteId).collection('datos').doc(nombre);
  CollectionReference<Map<String, dynamic>> _sub(String pacienteId, String nombre) =>
      _db.collection('pacientes').doc(pacienteId).collection(nombre);

  // Sin internet Firebase guarda en el celular y sube después; no se espera más de 10 s
  Future<void> _escribir(Future<Object?> f) => f.then((_) {}).timeout(const Duration(seconds: 10), onTimeout: () {});

  // Mensajes de error de Firebase en español
  ErrorCuenta _error(Object e) {
    if (e is FirebaseAuthException) {
      return ErrorCuenta(switch (e.code) {
        'email-already-in-use' => 'Ya existe una cuenta con ese correo',
        'invalid-email' => 'El correo no es válido',
        'weak-password' => 'La contraseña debe tener mínimo 6 caracteres',
        'network-request-failed' => 'Sin conexión a internet',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos',
        'requires-recent-login' => 'Por seguridad, cierra sesión y vuelve a entrar',
        _ => 'Correo o contraseña incorrectos',
      });
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      return ErrorCuenta('No tienes permiso para esta acción');
    }
    if (e is FirebaseException && e.code == 'unavailable') return ErrorCuenta('Sin conexión a internet');
    return ErrorCuenta('Ocurrió un error: $e');
  }

  // ---------------- Cuentas ----------------

  @override
  Future<Cuenta?> sesionActual() async {
    final u = await _auth.authStateChanges().first; // espera a que Firebase recupere la sesión
    return u == null ? null : cuenta(u.uid);
  }

  @override
  Future<Cuenta> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required Rol rol,
    String? tarjetaProfesional,
  }) async {
    try {
      final r = await _auth.createUserWithEmailAndPassword(email: correo.trim(), password: contrasena);
      final c = Cuenta(
        id: r.user!.uid,
        nombre: nombre.trim(),
        correo: correo.trim().toLowerCase(),
        rol: rol,
        creado: DateTime.now(),
        tarjetaProfesional: tarjetaProfesional?.trim(),
      );
      await _usuarios.doc(c.id).set(c.aMapa());
      return c;
    } catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<Cuenta> iniciarSesion(String correo, String contrasena) async {
    try {
      final r = await _auth.signInWithEmailAndPassword(email: correo.trim(), password: contrasena);
      final c = await cuenta(r.user!.uid);
      if (c == null) {
        await _auth.signOut();
        throw ErrorCuenta('La cuenta no tiene datos en SensoTech');
      }
      return c;
    } on ErrorCuenta {
      rethrow;
    } catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<Cuenta> cambiarClave(Cuenta c, String nueva) async {
    try {
      await _auth.currentUser!.updatePassword(nueva);
      final actualizada = c.copia(debeCambiarClave: false);
      await _usuarios.doc(c.id).update({'cambiarClave': false});
      return actualizada;
    } catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<Cuenta?> cuenta(String id) async {
    final d = await _usuarios.doc(id).get();
    final m = d.data();
    return m == null ? null : Cuenta.desdeMapa(m);
  }

  // El fisio crea la cuenta del paciente con una segunda conexión,
  // así su propia sesión no se cierra
  @override
  Future<Cuenta> crearPaciente({
    required Cuenta fisio,
    required String nombre,
    required String correo,
    required String claveTemporal,
    required FichaClinica ficha,
  }) async {
    FirebaseApp? segunda;
    try {
      segunda = Firebase.apps.where((a) => a.name == 'altas').firstOrNull ??
          await Firebase.initializeApp(name: 'altas', options: Firebase.app().options);
      final auth2 = FirebaseAuth.instanceFor(app: segunda);
      final r = await auth2.createUserWithEmailAndPassword(email: correo.trim(), password: claveTemporal);
      await auth2.signOut();

      final p = Cuenta(
        id: r.user!.uid,
        nombre: nombre.trim(),
        correo: correo.trim().toLowerCase(),
        rol: Rol.paciente,
        creado: DateTime.now(),
        fisioId: fisio.id,
        debeCambiarClave: true,
      );
      await _usuarios.doc(p.id).set(p.aMapa()); // primero la cuenta, luego la historia
      await guardarFicha(FichaClinica.desdeMapa({...ficha.aMapa(), 'pacienteId': p.id}));
      return p;
    } catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<List<Cuenta>> pacientesDe(String fisioId) async {
    final q = await _usuarios.where('fisioId', isEqualTo: fisioId).get();
    final l = q.docs.map((d) => Cuenta.desdeMapa(d.data())).toList();
    l.sort((a, b) => a.nombre.compareTo(b.nombre));
    return l;
  }

  // ---------------- Historia ----------------

  @override
  Future<FichaClinica?> ficha(String pacienteId) async {
    final m = (await _dato(pacienteId, 'ficha').get()).data();
    return m == null ? null : FichaClinica.desdeMapa(m);
  }

  @override
  Future<void> guardarFicha(FichaClinica f) => _escribir(_dato(f.pacienteId, 'ficha').set(f.aMapa()));

  @override
  Future<List<NotaEvolucion>> notas(String pacienteId) async {
    final q = await _sub(pacienteId, 'notas').get();
    final n = q.docs.map((d) => NotaEvolucion.desdeMapa(d.data())).toList();
    n.sort((a, b) => b.fecha.compareTo(a.fecha)); // más reciente primero
    return n;
  }

  @override
  Future<void> agregarNota(NotaEvolucion n) => _escribir(_sub(n.pacienteId, 'notas').add(n.aMapa()));

  // ---------------- Rutina, sesiones y agenda ----------------

  @override
  Future<Rutina?> rutina(String pacienteId) async {
    final m = (await _dato(pacienteId, 'rutina').get()).data();
    if (m == null) return null;
    try {
      return Rutina.desdeMapa(m);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardarRutina(String pacienteId, Rutina rutina) =>
      _escribir(_dato(pacienteId, 'rutina').set(rutina.aMapa()));

  @override
  Future<List<SesionRehab>> sesionesRehab(String pacienteId) async {
    final q = await _sub(pacienteId, 'sesiones').get();
    final s = <SesionRehab>[];
    for (final d in q.docs) {
      try {
        s.add(SesionRehab.desdeMapa(d.data()));
      } catch (_) {} // se ignora un registro dañado
    }
    s.sort((a, b) => a.fecha.compareTo(b.fecha)); // de la más vieja a la más reciente
    return s;
  }

  @override
  Future<void> guardarRehab(SesionRehab s) => _escribir(_sub(s.perfilId, 'sesiones').add(s.aMapa()));

  @override
  Future<Agenda?> agenda(String pacienteId) async {
    final m = (await _dato(pacienteId, 'agenda').get()).data();
    if (m == null) return null;
    try {
      return Agenda.desdeMapa(m);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardarAgenda(String pacienteId, Agenda agenda) =>
      _escribir(_dato(pacienteId, 'agenda').set(agenda.aMapa()));

  // ---------------- Demostración ----------------

  @override
  String idNuevo() => _usuarios.doc().id;

  @override
  Future<void> agregarCuentasDemo(List<Cuenta> nuevas) async {
    for (final c in nuevas) {
      await _usuarios.doc(c.id).set(c.aMapa());
    }
  }
}
