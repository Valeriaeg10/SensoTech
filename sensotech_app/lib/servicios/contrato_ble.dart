import 'dart:typed_data';
import '../modelos/datos_brazalete.dart';

// Contrato BLE SensoTech v1.1 (0001 ahora tiene 8 bytes)
// El simulado y el real usan estas mismas funciones.
class ContratoBle {
  static const servicio = '5e750000-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const angulosEnVivo = '5e750001-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const ejercicioEnCurso = '5e750002-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const modo = '5e750003-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const alerta = '5e750004-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const resumenDia = '5e750005-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const resultadosRehab = '5e750006-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const rutina = '5e750007-7ec4-4a1b-9c3d-2f6a8b1d0e11';
  static const sincronizacion = '5e750008-7ec4-4a1b-9c3d-2f6a8b1d0e11';

  // 0001: 8 bytes -> lectura
  static LecturaEnVivo leerAngulos(List<int> bytes) {
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    final flexion = d.getInt16(0, Endian.little) / 10; // décimas -> grados
    final desviacion = d.getInt16(2, Endian.little) / 10;
    final e = d.getUint8(4);
    final f = d.getUint8(5);
    final estado = EstadoPostura.values[e > 2 ? 2 : e];
    final fase = FaseBrazalete.values[f > 6 ? 6 : f];
    final antebrazo = d.getInt16(6, Endian.little) / 10; // IMU 1
    return LecturaEnVivo(
      flexion: flexion,
      desviacion: desviacion,
      estado: estado,
      fase: fase,
      antebrazo: antebrazo,
    );
  }

  // Lectura -> 8 bytes (lo usa el simulado, igual que el ESP32)
  static List<int> escribirAngulos(LecturaEnVivo l) {
    final d = ByteData(8);
    d.setInt16(0, (l.flexion * 10).round(), Endian.little);
    d.setInt16(2, (l.desviacion * 10).round(), Endian.little);
    d.setUint8(4, l.estado.index);
    d.setUint8(5, l.fase.index);
    d.setInt16(6, (l.antebrazo * 10).round(), Endian.little);
    return d.buffer.asUint8List();
  }

  // 0003: modo + tipo de trabajo (255 = sin elegir)
  static List<int> escribirModo(ModoBrazalete modo, int? tipoTrabajo) {
    return [modo.index, tipoTrabajo ?? 255];
  }

  // 0002: 8 bytes -> ejercicio en curso
  static EjercicioEnCurso leerEjercicio(List<int> bytes) {
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    final t = d.getUint8(0);
    return EjercicioEnCurso(
      tipo: TipoEjercicio.values[t > 3 ? 3 : t],
      objetivo: d.getInt16(1, Endian.little) / 10,
      repeticion: d.getUint8(3),
      repeticionesTotal: d.getUint8(4),
      serie: d.getUint8(5),
      seriesTotal: d.getUint8(6),
      descanso: d.getUint8(7),
    );
  }

  // Ejercicio -> 8 bytes (lo usa el simulado, igual que el ESP32)
  static List<int> escribirEjercicio(EjercicioEnCurso e) {
    final d = ByteData(8);
    d.setUint8(0, e.tipo.index);
    d.setInt16(1, (e.objetivo * 10).round(), Endian.little);
    d.setUint8(3, e.repeticion);
    d.setUint8(4, e.repeticionesTotal);
    d.setUint8(5, e.serie);
    d.setUint8(6, e.seriesTotal);
    d.setUint8(7, e.descanso);
    return d.buffer.asUint8List();
  }
}
