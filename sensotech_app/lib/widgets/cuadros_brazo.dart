import 'package:flutter/material.dart';

// Datos de las imágenes 3D del brazo (generadas a partir del modelo, 704 x 368 px)
class CuadrosBrazo {
  static const ancho = 704.0;
  static const alto = 368.0;
  static const paso = 5; // grados entre imágenes

  // Rangos disponibles
  static const latMin = -70, latMax = 80; // flexión (+) / extensión (−)
  static const supMin = -30, supMax = 25; // desviación radial (+) / cubital (−)

  // Centro de giro de la muñeca
  static const munecaLat = Offset(406.5, 184.0);
  static const munecaSup = Offset(409.0, 184.0);

  // Módulo del brazalete (IMU 1)
  static const moduloLat = Offset(332.9, 160.4);
  static const moduloSup = Offset(320.6, 184.0);

  // Pantalla del brazalete en la vista desde arriba
  static const pantallaSup = Rect.fromLTRB(305, 166, 335, 201);

  // Posición de la IMU 2 en cada imagen
  static const imu2Lat = <int, Offset>{
    -70: Offset(392.1, 142.9),
    -65: Offset(395.7, 141.8),
    -60: Offset(399.5, 141.0),
    -55: Offset(403.2, 140.5),
    -50: Offset(407.0, 140.4),
    -45: Offset(410.8, 140.6),
    -40: Offset(414.6, 141.2),
    -35: Offset(418.3, 142.0),
    -30: Offset(421.9, 143.2),
    -25: Offset(425.4, 144.7),
    -20: Offset(428.8, 146.5),
    -15: Offset(431.9, 148.6),
    -10: Offset(434.9, 151.0),
    -5: Offset(437.7, 153.6),
    0: Offset(440.2, 156.4),
    5: Offset(442.5, 159.4),
    10: Offset(444.5, 162.7),
    15: Offset(446.2, 166.1),
    20: Offset(447.6, 169.6),
    25: Offset(448.7, 173.2),
    30: Offset(449.5, 177.0),
    35: Offset(450.0, 180.7),
    40: Offset(450.1, 184.5),
    45: Offset(449.9, 188.3),
    50: Offset(449.3, 192.1),
    55: Offset(448.5, 195.8),
    60: Offset(447.3, 199.4),
    65: Offset(445.8, 202.9),
    70: Offset(444.0, 206.3),
    75: Offset(441.9, 209.4),
    80: Offset(439.5, 212.4),
  };
  static const imu2Sup = <int, Offset>{
    -30: Offset(444.0, 204.2),
    -25: Offset(445.6, 201.1),
    -20: Offset(447.0, 197.8),
    -15: Offset(448.1, 194.5),
    -10: Offset(448.8, 191.0),
    -5: Offset(449.3, 187.5),
    0: Offset(449.4, 184.0),
    5: Offset(449.3, 180.5),
    10: Offset(448.8, 177.0),
    15: Offset(448.1, 173.5),
    20: Offset(447.0, 170.2),
    25: Offset(445.6, 166.9),
  };
}
