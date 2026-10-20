import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import 'icono_chip.dart';
import 'indicador_estado.dart';
import 'vista_brazo.dart';

// Tarjeta con el brazo en vivo y selector de vista
class TarjetaMovimiento extends StatefulWidget {
  final LecturaEnVivo lectura;

  const TarjetaMovimiento({super.key, required this.lectura});

  @override
  State<TarjetaMovimiento> createState() => _TarjetaMovimientoState();
}

class _TarjetaMovimientoState extends State<TarjetaMovimiento> {
  TipoVista _vista = TipoVista.lateral;

  @override
  Widget build(BuildContext context) {
    final l = widget.lectura;
    final lateral = _vista == TipoVista.lateral;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoChip(icono: Icons.accessibility_new_rounded, tamano: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Movimiento en vivo', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(lateral ? 'Flexión y extensión' : 'Hacia el pulgar o el meñique',
                        style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Selector de vista
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TipoVista>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TipoVista.lateral,
                  icon: Icon(Icons.swap_vert_rounded),
                  label: Text('Lateral'),
                ),
                ButtonSegment(
                  value: TipoVista.superior,
                  icon: Icon(Icons.swap_horiz_rounded),
                  label: Text('Superior'),
                ),
              ],
              selected: {_vista},
              onSelectionChanged: (s) => setState(() => _vista = s.first),
            ),
          ),
          const SizedBox(height: 12),
          VistaBrazo(
            vista: _vista,
            flexion: l.flexion,
            desviacion: l.desviacion,
            antebrazo: l.antebrazo,
            colorEstado: colorDeEstado(l.estado),
          ),
          const SizedBox(height: 10),
          // Leyenda
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (lateral) const _ItemLeyenda(numero: '1', texto: 'IMU antebrazo'),
              const _ItemLeyenda(numero: '2', texto: 'IMU mano'),
              const _ItemLeyenda(texto: 'Mano recta', punteada: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemLeyenda extends StatelessWidget {
  final String? numero;
  final String texto;
  final bool punteada;

  const _ItemLeyenda({this.numero, required this.texto, this.punteada = false});

  @override
  Widget build(BuildContext context) {
    final Widget marca = punteada
        ? const Text('- - -', style: TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w700))
        : Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colores.primario, shape: BoxShape.circle),
            child: Text(numero ?? '',
                style: const TextStyle(color: Colores.blanco, fontSize: 10, fontWeight: FontWeight.w700)),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marca,
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
      ],
    );
  }
}
