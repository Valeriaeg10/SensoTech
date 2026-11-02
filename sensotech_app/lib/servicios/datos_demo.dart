import 'dart:math';
import '../modelos/agenda.dart';
import '../modelos/cuenta.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ejercicios.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';
import 'nube.dart';

// Crea 3 pacientes de ejemplo con ficha clínica e historial, para mostrar el perfil del fisio.
// Quedan marcados como "Demo".
Future<void> crearPacientesDemo(Cuenta fisio) async {
  final azar = Random(7);
  final hoy = DateTime.now();

  // (nombre, correo, documento, nacimiento, sexo, ocupación, ángulos iniciales, mejora, (sin uso), dolor inicial)
  final ejemplos = [
    ('Laura Gómez', 'laura.demo@sensotech.co', '1036654321', DateTime(1988, 4, 12), 'Femenino',
        'Auxiliar contable', [38.0, 30.0, 9.0, 14.0], 1.6, 1, 7),
    ('Carlos Pérez', 'carlos.demo@sensotech.co', '71234567', DateTime(1979, 9, 3), 'Masculino',
        'Operario de ensamble', [44.0, 38.0, 12.0, 18.0], 0.6, 5, 5),
    ('Ana Ruiz', 'ana.demo@sensotech.co', '1017223344', DateTime(1995, 1, 25), 'Femenino',
        'Digitadora', [30.0, 26.0, 7.0, 11.0], 1.0, 12, 8),
  ];

  final cuentas = <Cuenta>[];
  for (final e in ejemplos) {
    final c = Cuenta(
      id: nube.idNuevo(),
      nombre: e.$1,
      correo: e.$2,
      rol: Rol.paciente,
      creado: hoy.subtract(const Duration(days: 40)),
      fisioId: fisio.id,
      demo: true,
    );
    cuentas.add(c);
    await nube.agregarCuentasDemo([c]); // primero la cuenta: las reglas de Firebase lo exigen

    await nube.guardarFicha(FichaClinica(
      pacienteId: c.id,
      numeroDocumento: e.$3,
      fechaNacimiento: e.$4,
      sexo: e.$5,
      ocupacion: e.$6,
      telefono: '300 000 0000',
      direccion: 'Medellín',
      eps: 'EPS de ejemplo',
      acompanante: 'Familiar de ejemplo',
      acompananteParentesco: 'Cónyuge',
      acompananteTelefono: '301 000 0000',
      manoDominante: 'Derecha',
      manoAfectada: 'Derecha',
      fechaValoracion: hoy.subtract(const Duration(days: 38)),
      motivoConsulta: 'Hormigueo y dolor en la mano derecha, peor en la noche y al usar el computador.',
      antecedentes: 'Sin antecedentes quirúrgicos de miembro superior.',
      dolorInicial: e.$10,
      goniometria: {
        TipoEjercicio.flexion: e.$7[0],
        TipoEjercicio.extension: e.$7[1],
        TipoEjercicio.radial: e.$7[2],
        TipoEjercicio.cubital: e.$7[3],
      },
      phalen: ResultadoPrueba.positiva,
      tinel: ResultadoPrueba.positiva,
      durkan: ResultadoPrueba.negativa,
      bctq: 2.8,
      objetivos: 'Disminuir el dolor a 3/10 o menos y recuperar el rango de flexión y extensión.',
    ));

    // Programación: Laura mar y jue 11:00 (al día) · Carlos lun-mié-vie 8:00 (faltó 1) · Ana mar 15:00 (faltó 2)
    final (dias, hora, total, faltas) = switch (cuentas.length) {
      1 => ([2, 4], 11, 12, <int>{}),
      2 => ([1, 3, 5], 8, 15, <int>{-1}),
      _ => ([2], 15, 8, <int>{-1, -2}),
    };
    final agenda = Agenda(
      dias: dias,
      hora: hora,
      minuto: 0,
      inicio: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 28)),
      totalSesiones: total,
      actualizada: hoy.subtract(const Duration(days: 30)),
    );
    await nube.guardarAgenda(c.id, agenda);

    // Sesiones hechas en las fechas programadas que ya pasaron (menos las faltas: −1 = la última)
    final pasadas = agenda.sesiones().where((x) => x.fecha.isBefore(hoy) && !mismoDia(x.fecha, hoy)).toList();
    var i = 0;
    for (var j = 0; j < pasadas.length; j++) {
      if (faltas.contains(j - pasadas.length)) continue;
      final fecha = pasadas[j].fecha.add(Duration(minutes: azar.nextInt(20)));
      double v(int k, double tope) =>
          min(tope, e.$7[k] + e.$8 * i * (k < 2 ? 1 : 0.35) + azar.nextDouble() * 2 - 1);
      final dolor = max(1, e.$10 - (i * 0.6).round());
      await nube.guardarRehab(SesionRehab(
        perfilId: c.id,
        fecha: fecha,
        flexion: v(0, 80),
        extension: v(1, 70),
        radial: v(2, 20),
        cubital: v(3, 30),
        completa: i != 3, // una sesión incompleta, como pasa en la vida real
        dolorAntes: dolor,
        dolorDespues: max(0, dolor - 1 - azar.nextInt(2)),
        realizados: Rutina.predefinida().ejercicios,
      ));
      i++;
    }

    await nube.agregarNota(NotaEvolucion(
      pacienteId: c.id,
      fecha: hoy.subtract(const Duration(days: 20)),
      texto: 'Buena adherencia. Se mantiene el uso de férula nocturna en posición neutra.',
      autor: fisio.nombre,
      tarjeta: fisio.tarjetaProfesional ?? '',
    ));
  }

  // Laura ya tiene una rutina asignada, con una meta fija
  await nube.guardarRutina(
    cuentas.first.id,
    Rutina(
      ejercicios: const [
        EjercicioRutina(id: IdEjercicio.r1Tendones, series: 3, repeticiones: 10, meta: 42),
        EjercicioRutina(id: IdEjercicio.r2Extension, series: 2, repeticiones: 10),
        EjercicioRutina(id: IdEjercicio.r3Pendulo, series: 2, repeticiones: 15),
      ],
      descanso: 30,
      actualizada: hoy.subtract(const Duration(days: 6)),
      nota: 'Movimientos lentos y sin dolor. Hielo 10 minutos al terminar.',
    ),
  );
}
