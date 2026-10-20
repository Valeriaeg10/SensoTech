import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../tema/colores.dart';

// Color del semáforo según el estado
Color colorDeEstado(EstadoPostura e) => switch (e) {
      EstadoPostura.verde => Colores.verde,
      EstadoPostura.amarillo => Colores.amarillo,
      EstadoPostura.rojo => Colores.rojo,
    };

// Semáforo de postura: color + ícono + texto (se entiende sin ver el color)
class IndicadorEstado extends StatelessWidget {
  final EstadoPostura estado;

  const IndicadorEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = colorDeEstado(estado);
    final (icono, titulo, detalle) = switch (estado) {
      EstadoPostura.verde => (Icons.check_rounded, 'Postura segura', 'Muñeca dentro del rango'),
      EstadoPostura.amarillo => (Icons.priority_high_rounded, 'Precaución', 'Muñeca fuera de rango'),
      EstadoPostura.rojo => (Icons.close_rounded, 'Vuelve a la posición normal', 'Más de 4 s fuera de rango'),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icono, color: Colores.blanco, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colores.texto, fontSize: 17, fontWeight: FontWeight.w700)),
                Text(detalle, style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
