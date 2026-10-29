import 'dart:typed_data';
import '../modelos/datos_brazalete.dart';

// Contrato BLE SensoTech v2
// El simulado y el real usan estas mismas funciones.
class ContratoBle {
  static const servicio = '5e750000-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const angulosEnVivo = '5e750001-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Notify, 8 bytes
  static const ejercicioEnCurso = '5e750002-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Notify, 10 bytes
  static const modo = '5e750003-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Read/Write, 2 bytes
  static const alerta = '5e750004-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Notify, 3 bytes
  static const resumenDia = '5e750005-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Read/Notify, 16 bytes
  static const resultadosRehab = '5e750006-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Read/Notify, 13 bytes
  static const rutina = '5e750007-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Write, 2 + 4 por ejercicio
  static const sincronizacion = '5e750008-7ec4-4a1b-9c3d-2f6a8b1d0e11'; // Write, 13 bytes

  static ByteData _d(List<int> b) => ByteData.sublistView(Uint8List.fromList(b));

  // 0001: flexión, desviación (int16 décimas), estado, fase, antebrazo (int16 décimas)
  static LecturaEnVivo leerAngulos(List<int> bytes) {
    final d = _d(bytes);
    final e = d.getUint8(4), f = d.getUint8(5);
    return LecturaEnVivo(
      flexion: d.getInt16(0, Endian.little) / 10,
      desviacion: d.getInt16(2, Endian.little) / 10,
      estado: EstadoPostura.values[e > 2 ? 2 : e],
      fase: FaseBrazalete.values[f > 6 ? 6 : f],
      antebrazo: d.getInt16(6, Endian.little) / 10,
    );
  }

  static List<int> escribirAngulos(LecturaEnVivo l) {
    final d = ByteData(8);
    d.setInt16(0, (l.flexion * 10).round(), Endian.little);
    d.setInt16(2, (l.desviacion * 10).round(), Endian.little);
    d.setUint8(4, l.estado.index);
    d.setUint8(5, l.fase.index);
    d.setInt16(6, (l.antebrazo * 10).round(), Endian.little);
    return d.buffer.asUint8List();
  }

  // 0002: código, objetivo (int16 décimas, con signo), repetición, total, serie, total,
  //       descanso (s), sostener (s), zona (0 normal, 1 en meta, 2 riesgo)
  static EjercicioEnCurso leerEjercicio(List<int> bytes) {
    final d = _d(bytes);
    final z = d.getUint8(9);
    return EjercicioEnCurso(
      codigo: d.getUint8(0),
      objetivo: d.getInt16(1, Endian.little) / 10,
      repeticion: d.getUint8(3),
      repeticionesTotal: d.getUint8(4),
      serie: d.getUint8(5),
      seriesTotal: d.getUint8(6),
      descanso: d.getUint8(7),
      sostener: d.getUint8(8),
      zona: ZonaEjercicio.values[z > 2 ? 2 : z],
    );
  }

  static List<int> escribirEjercicio(EjercicioEnCurso e) {
    final d = ByteData(10);
    d.setUint8(0, e.codigo);
    d.setInt16(1, (e.objetivo * 10).round(), Endian.little);
    d.setUint8(3, e.repeticion);
    d.setUint8(4, e.repeticionesTotal);
    d.setUint8(5, e.serie);
    d.setUint8(6, e.seriesTotal);
    d.setUint8(7, e.descanso);
    d.setUint8(8, e.sostener);
    d.setUint8(9, e.zona.index);
    return d.buffer.asUint8List();
  }

  // 0003: modo + tipo de trabajo (255 = sin elegir)
  static List<int> escribirModo(ModoBrazalete modo, int? tipoTrabajo) => [modo.index, tipoTrabajo ?? 255];

  // 0006: fecha (uint32, segundos desde 1970), 4 máximos (int16 décimas), completa
  static ResultadoRehab leerResultados(List<int> bytes) {
    final d = _d(bytes);
    final seg = d.getUint32(0, Endian.little);
    return ResultadoRehab(
      fecha: DateTime.fromMillisecondsSinceEpoch(seg * 1000),
      maximos: {
        for (var i = 0; i < 4; i++) TipoEjercicio.values[i]: d.getInt16(4 + i * 2, Endian.little) / 10,
      },
      completa: d.getUint8(12) == 1,
    );
  }

  static List<int> escribirResultados(ResultadoRehab r) {
    final d = ByteData(13);
    d.setUint32(0, r.fecha.millisecondsSinceEpoch ~/ 1000, Endian.little);
    for (var i = 0; i < 4; i++) {
      d.setInt16(4 + i * 2, ((r.maximos[TipoEjercicio.values[i]] ?? 0) * 10).round(), Endian.little);
    }
    d.setUint8(12, r.completa ? 1 : 0);
    return d.buffer.asUint8List();
  }

  // 0008: hora actual (uint32), 4 últimos máximos (int16 décimas, 0 = sin dato), mano (0 der, 1 izq)
  static List<int> escribirSincronizacion(DateTime ahora, Map<TipoEjercicio, double>? ultimos, int mano) {
    final d = ByteData(13);
    final u = ultimos ?? const <TipoEjercicio, double>{};
    d.setUint32(0, ahora.millisecondsSinceEpoch ~/ 1000, Endian.little);
    for (var i = 0; i < 4; i++) {
      d.setInt16(4 + i * 2, ((u[TipoEjercicio.values[i]] ?? 0) * 10).round(), Endian.little);
    }
    d.setUint8(12, mano);
    return d.buffer.asUint8List();
  }

  // Lo que lee el brazalete de 0008 (mismo formato). Últimos = null si todos vienen en 0.
  static (DateTime, Map<TipoEjercicio, double>?, int) leerSincronizacion(List<int> bytes) {
    final d = _d(bytes);
    final m = <TipoEjercicio, double>{};
    for (var i = 0; i < 4; i++) {
      final v = d.getInt16(4 + i * 2, Endian.little) / 10;
      if (v != 0) m[TipoEjercicio.values[i]] = v;
    }
    return (
      DateTime.fromMillisecondsSinceEpoch(d.getUint32(0, Endian.little) * 1000),
      m.isEmpty ? null : m,
      d.getUint8(12),
    );
  }

  // Lo que lee el brazalete de 0007: descanso y lista de (ejercicio, series, repeticiones, meta; 0 = progresiva)
  static (int, List<(int, int, int, int)>) leerRutina(List<int> bytes) {
    final n = bytes[0];
    return (
      bytes[1],
      [for (var i = 0; i < n; i++) (bytes[2 + i * 4], bytes[3 + i * 4], bytes[4 + i * 4], bytes[5 + i * 4])],
    );
  }
}
