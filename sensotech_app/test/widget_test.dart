import 'package:flutter_test/flutter_test.dart';
import 'package:sensotech_app/modelos/agenda.dart';
import 'package:sensotech_app/modelos/datos_brazalete.dart';
import 'package:sensotech_app/modelos/ejercicios.dart';
import 'package:sensotech_app/modelos/rutina.dart';
import 'package:sensotech_app/servicios/contrato_ble.dart';

// Pruebas del contrato BLE: lo que se escribe en bytes se lee igual
void main() {
  test('0001 ángulos en vivo (8 bytes)', () {
    const original = LecturaEnVivo(
      flexion: 15.3,
      desviacion: -2.0,
      estado: EstadoPostura.amarillo,
      fase: FaseBrazalete.pausaActiva,
      antebrazo: 10.5,
    );
    final bytes = ContratoBle.escribirAngulos(original);
    final leida = ContratoBle.leerAngulos(bytes);

    expect(bytes.length, 8);
    expect(leida.flexion, 15.3);
    expect(leida.desviacion, -2.0);
    expect(leida.estado, EstadoPostura.amarillo);
    expect(leida.fase, FaseBrazalete.pausaActiva);
    expect(leida.antebrazo, 10.5);
  });

  test('0002 ejercicio en curso (10 bytes)', () {
    const original = EjercicioEnCurso(
      codigo: 1,
      objetivo: -42.5,
      repeticion: 3,
      repeticionesTotal: 10,
      serie: 2,
      seriesTotal: 2,
      descanso: 0,
      sostener: 7,
      zona: ZonaEjercicio.enMeta,
    );
    final bytes = ContratoBle.escribirEjercicio(original);
    final e = ContratoBle.leerEjercicio(bytes);

    expect(bytes.length, 10);
    expect(e.codigo, 1);
    expect(e.objetivo, -42.5);
    expect(e.repeticion, 3);
    expect(e.repeticionesTotal, 10);
    expect(e.serie, 2);
    expect(e.sostener, 7);
    expect(e.zona, ZonaEjercicio.enMeta);
    expect(e.esEvaluacion, false);
  });

  test('0006 resultados de rehabilitación (13 bytes)', () {
    final original = ResultadoRehab(
      fecha: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      maximos: const {
        TipoEjercicio.flexion: 44.2,
        TipoEjercicio.extension: 38.0,
        TipoEjercicio.radial: 14.5,
        TipoEjercicio.cubital: 21.1,
      },
      completa: true,
    );
    final bytes = ContratoBle.escribirResultados(original);
    final r = ContratoBle.leerResultados(bytes);

    expect(bytes.length, 13);
    expect(r.fecha, original.fecha);
    expect(r.maximos[TipoEjercicio.flexion], 44.2);
    expect(r.maximos[TipoEjercicio.cubital], 21.1);
    expect(r.completa, true);
  });

  test('0007 rutina (2 + 4 bytes por ejercicio)', () {
    final rutina = Rutina(
      ejercicios: const [
        EjercicioRutina(id: IdEjercicio.r1Tendones, series: 3, repeticiones: 10, meta: 42),
        EjercicioRutina(id: IdEjercicio.r3Pendulo, series: 2, repeticiones: 15),
      ],
      descanso: 30,
      actualizada: DateTime(2026, 10, 28),
    );
    final bytes = rutina.aBytes();
    final leida = ContratoBle.leerRutina(bytes);

    expect(bytes.length, 2 + 4 * 2);
    expect(leida.$1, 30);
    expect(leida.$2[0], (0, 3, 10, 42));
    expect(leida.$2[1], (2, 2, 15, 0)); // 0 = meta progresiva
  });

  test('0008 sincronización (13 bytes)', () {
    final bytes = ContratoBle.escribirSincronizacion(
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      const {TipoEjercicio.flexion: 40.0, TipoEjercicio.radial: 12.5},
      1,
    );
    final s = ContratoBle.leerSincronizacion(bytes);

    expect(bytes.length, 13);
    expect(s.$2![TipoEjercicio.flexion], 40.0);
    expect(s.$2![TipoEjercicio.radial], 12.5);
    expect(s.$2!.containsKey(TipoEjercicio.extension), false);
    expect(s.$3, 1); // mano izquierda
    expect(ContratoBle.leerSincronizacion(ContratoBle.escribirSincronizacion(DateTime.now(), null, 0)).$2, null);
  });

  test('Meta progresiva: último máximo + 5°, con tope', () {
    final r1 = catalogo[IdEjercicio.r1Tendones]!;
    expect(metaProgresiva(r1, null), 40);
    expect(metaProgresiva(r1, const {TipoEjercicio.flexion: 30}), 35);
    expect(metaProgresiva(r1, const {TipoEjercicio.flexion: 44}), 45);
  });

  test('Agenda: martes y jueves, reprogramar y cancelar', () {
    var a = Agenda(dias: const [2, 4], hora: 11, minuto: 0, inicio: DateTime(2026, 11, 2), totalSesiones: 5,
        actualizada: DateTime(2026, 11, 2));
    final s = a.sesiones();
    expect(s.length, 5);
    expect(s.first.fecha, DateTime(2026, 11, 3, 11));
    a = a.conCambio(s[1].original, DateTime(2026, 11, 7, 9, 30)).conCambio(s[2].original, null);
    expect(a.sesiones().length, 5); // la cancelada se repone al final
    expect(a.sesiones()[1].fecha, DateTime(2026, 11, 7, 9, 30));
  });
}
