import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/perfil.dart';
import '../servicios/brazalete.dart';
import '../servicios/repositorio_perfiles.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';
import 'historial_pantalla.dart';
import 'prevencion_pantalla.dart';

// Panel: conectar el brazalete y elegir el modo (hoja 1)
class PanelPantalla extends StatefulWidget {
  final Perfil perfil;
  final Brazalete brazalete;

  const PanelPantalla({super.key, required this.perfil, required this.brazalete});

  @override
  State<PanelPantalla> createState() => _PanelPantallaState();
}

class _PanelPantallaState extends State<PanelPantalla> {
  bool _conectando = false;
  late Perfil _perfil = widget.perfil; // se actualiza con el último tipo de trabajo

  Brazalete get _b => widget.brazalete;

  @override
  void dispose() {
    _b.desconectar(); // al salir del perfil se desconecta
    super.dispose();
  }

  Future<void> _alternarConexion() async {
    if (_b.conectado) {
      await _b.desconectar();
      setState(() {});
      return;
    }
    setState(() => _conectando = true);
    await _b.conectar();
    if (!mounted) return;
    setState(() => _conectando = false);
  }

  Future<void> _abrirPrevencion() async {
    // Hoja 1: en prevención se elige el tipo de trabajo
    final tipo = await showModalBottomSheet<TipoTrabajo>(
      context: context,
      backgroundColor: Colores.fondo,
      showDragHandle: true,
      builder: (_) => _SelectorTipo(inicial: _perfil.ultimoTipo),
    );
    if (tipo == null || !mounted) return; // canceló

    _perfil = _perfil.conTipo(tipo);
    await RepositorioPerfiles().guardar(_perfil); // recuerda la elección
    await _b.enviarModo(ModoBrazalete.prevencion, tipoTrabajo: tipo.index);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrevencionPantalla(perfil: _perfil, tipo: tipo, brazalete: _b),
      ),
    );
    await _b.enviarModo(ModoBrazalete.menu); // al volver, menú de modo
  }

  @override
  Widget build(BuildContext context) {
    final conectado = _b.conectado;
    return Scaffold(
      appBar: AppBar(title: Text(_perfil.nombre)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _tarjetaConexion(),
            const SizedBox(height: 24),
            const Text('Elige el modo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(conectado ? 'También se puede elegir con el botón del brazalete' : 'Conecta el brazalete primero',
                style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
            const SizedBox(height: 14),
            _tarjetaModo(
              icono: Icons.shield_outlined,
              titulo: 'Prevención',
              detalle: 'Vigila la postura en la jornada y avisa la pausa activa',
              activo: conectado,
              alTocar: _abrirPrevencion,
            ),
            const SizedBox(height: 12),
            _tarjetaModo(
              icono: Icons.fitness_center_rounded,
              titulo: 'Rehabilitación',
              detalle: 'Rutina guiada, línea base y evaluación de progreso',
              activo: false,
              etiqueta: 'Próximamente',
              alTocar: () {},
            ),
            const SizedBox(height: 24),
            const Text('Progreso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _tarjetaModo(
              icono: Icons.insert_chart_outlined_rounded,
              titulo: 'Historial',
              detalle: 'Jornadas guardadas y gráfica de progreso',
              activo: true,
              alTocar: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistorialPantalla(perfil: _perfil)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaConexion() {
    final conectado = _b.conectado;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        children: [
          Row(
            children: [
              IconoChip(
                icono: conectado ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conectado ? _b.nombre : 'Brazalete desconectado',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(conectado ? 'Conectado' : 'Toca conectar para empezar',
                        style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
                  ],
                ),
              ),
              if (conectado) ...[
                const Icon(Icons.battery_5_bar_rounded, size: 20, color: Colores.verde),
                Text(' ${_b.bateria} %',
                    style: const TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          conectado
              ? OutlinedButton.icon(
                  onPressed: _alternarConexion,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Desconectar'),
                )
              : FilledButton.icon(
                  onPressed: _conectando ? null : _alternarConexion,
                  icon: _conectando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colores.blanco),
                        )
                      : const Icon(Icons.bluetooth_searching_rounded),
                  label: Text(_conectando ? 'Buscando…' : 'Conectar brazalete'),
                ),
        ],
      ),
    );
  }

  Widget _tarjetaModo({
    required IconData icono,
    required String titulo,
    required String detalle,
    required bool activo,
    required VoidCallback alTocar,
    String? etiqueta,
  }) {
    return Opacity(
      opacity: activo ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: activo ? alTocar : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Row(
            children: [
              IconoChip(icono: icono, tamano: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        if (etiqueta != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colores.azulSuave,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(etiqueta,
                                style: const TextStyle(fontSize: 11, color: Colores.primario)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(detalle, style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colores.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

// Hoja para elegir el tipo de trabajo antes de prevención
class _SelectorTipo extends StatefulWidget {
  final TipoTrabajo? inicial;

  const _SelectorTipo({this.inicial});

  @override
  State<_SelectorTipo> createState() => _SelectorTipoState();
}

class _SelectorTipoState extends State<_SelectorTipo> {
  late TipoTrabajo _tipo = widget.inicial ?? TipoTrabajo.administrativo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de trabajo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Define cada cuánto toca la pausa activa',
                style: TextStyle(color: Colores.textoSuave, fontSize: 13)),
            const SizedBox(height: 16),
            _opcion(TipoTrabajo.administrativo, Icons.computer_rounded, 'Oficina, computador'),
            const SizedBox(height: 10),
            _opcion(TipoTrabajo.repetitivo, Icons.precision_manufacturing_rounded, 'Movimientos repetidos de la mano'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _tipo),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar prevención'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion(TipoTrabajo tipo, IconData icono, String detalle) {
    final sel = _tipo == tipo;
    return GestureDetector(
      onTap: () => setState(() => _tipo = tipo),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: decoracionTarjeta().copyWith(
          border: Border.all(color: sel ? Colores.primario : Colores.borde, width: sel ? 2 : 1),
        ),
        child: Row(
          children: [
            IconoChip(icono: icono),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo.texto, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('$detalle · pausa cada ${tipo.minutosPausa} min',
                      style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                ],
              ),
            ),
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel ? Colores.primario : Colores.textoSuave),
          ],
        ),
      ),
    );
  }
}
