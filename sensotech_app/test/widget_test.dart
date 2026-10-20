import 'package:flutter_test/flutter_test.dart';
import 'package:sensotech_app/modelos/datos_brazalete.dart';
import 'package:sensotech_app/servicios/contrato_ble.dart';

// Prueba: lo que se escribe en bytes se lee igual (contrato BLE)
void main() {
  test('Ida y vuelta de la característica 0001', () {
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
}
