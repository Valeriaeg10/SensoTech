import '../modelos/cuenta.dart';
import '../modelos/rutina.dart';
import 'nube.dart';

// Constancia del paciente según su última sesión
enum Constancia { alDia, pendiente, inactivo }

// Lo que el fisio ve de un paciente: solo rehabilitación (prevención es privada del paciente)
class ResumenPaciente {
  final Cuenta cuenta;
  final List<SesionRehab> rehab; // de la más vieja a la más reciente
  final Rutina? rutina;

  ResumenPaciente(this.cuenta, this.rehab, this.rutina);

  static Future<ResumenPaciente> cargar(Cuenta c) async => ResumenPaciente(
        c,
        await nube.sesionesRehab(c.id),
        await nube.rutina(c.id),
      );

  DateTime? get ultimaActividad => rehab.isEmpty ? null : rehab.last.fecha;

  int? get diasSinActividad {
    final u = ultimaActividad;
    return u == null ? null : DateTime.now().difference(u).inDays;
  }

  // Al día: ≤ 3 días · Pendiente: 4 a 7 · Inactivo: > 7 o sin sesiones
  Constancia get constancia {
    final d = diasSinActividad;
    if (d == null || d > 7) return Constancia.inactivo;
    if (d > 3) return Constancia.pendiente;
    return Constancia.alDia;
  }

  String get textoActividad {
    final d = diasSinActividad;
    if (d == null) return 'Sin sesiones de rehabilitación';
    if (d == 0) return 'Última sesión hoy';
    if (d == 1) return 'Última sesión ayer';
    return 'Última sesión hace $d días';
  }
}
