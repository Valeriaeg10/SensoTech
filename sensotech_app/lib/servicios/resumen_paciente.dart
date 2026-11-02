import '../modelos/agenda.dart';
import '../modelos/cuenta.dart';
import '../modelos/rutina.dart';
import 'nube.dart';

// Constancia del paciente según su programación
enum Constancia { alDia, pendiente, inactivo, sinProgramar }

// Lo que el fisio ve de un paciente: solo rehabilitación (prevención es privada del paciente)
class ResumenPaciente {
  final Cuenta cuenta;
  final List<SesionRehab> rehab; // de la más vieja a la más reciente
  final Rutina? rutina;
  final Agenda? agenda;

  ResumenPaciente(this.cuenta, this.rehab, this.rutina, this.agenda);

  static Future<ResumenPaciente> cargar(Cuenta c) async => ResumenPaciente(
        c,
        await nube.sesionesRehab(c.id),
        await nube.rutina(c.id),
        await nube.agenda(c.id),
      );

  Cumplimiento? get cumplimiento => agenda == null ? null : Cumplimiento(agenda!, rehab);

  // Al día: no faltó a las últimas sesiones · Pendiente: faltó a 1 · Inactivo: faltó a 2 o más
  Constancia get constancia {
    final c = cumplimiento;
    if (c == null) return Constancia.sinProgramar;
    final p = c.perdidasRecientes;
    if (p == 0) return Constancia.alDia;
    if (p == 1) return Constancia.pendiente;
    return Constancia.inactivo;
  }

  // "Sesión 5 de 12 · próxima mar 4 nov · 11:00"
  String get textoActividad {
    final c = cumplimiento;
    if (c == null) return 'Sin sesiones programadas';
    final p = c.proxima;
    if (p == null) return 'Plan terminado: ${c.realizadas} de ${c.total} realizadas';
    return 'Sesión ${c.numeroProxima} de ${c.total} · ${fechaSesion(p.fecha)}';
  }
}
