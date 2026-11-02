import 'package:flutter/material.dart';
import '../modelos/agenda.dart';
import '../modelos/cuenta.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';

// Color e ícono de cada estado de una sesión programada
(Color, IconData, String) estiloProgramada(EstadoProgramada e) => switch (e) {
      EstadoProgramada.realizada => (Colores.verde, Icons.check_circle_rounded, 'Realizada'),
      EstadoProgramada.perdida => (Colores.rojo, Icons.cancel_rounded, 'No asistió'),
      EstadoProgramada.hoy => (Colores.primario, Icons.today_rounded, 'Hoy'),
      EstadoProgramada.pendiente => (Colores.textoSuave, Icons.schedule_rounded, 'Pendiente'),
    };

// Pestaña del fisio: programación del paciente, cumplimiento y reprogramación
class PestanaAgenda extends StatelessWidget {
  final Cuenta paciente;
  final Agenda? agenda;
  final List<SesionRehab> sesiones;
  final Future<void> Function() alGuardar;

  const PestanaAgenda({
    super.key,
    required this.paciente,
    required this.agenda,
    required this.sesiones,
    required this.alGuardar,
  });

  Future<void> _editar(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditarAgendaPantalla(paciente: paciente, agenda: agenda)),
    );
    if (ok == true) await alGuardar();
  }

  // Mover una sesión a otro día u hora, o cancelarla
  Future<void> _reprogramar(BuildContext context, SesionProgramada s) async {
    final a = agenda!;
    final accion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Sesión del ${fechaSesion(s.fecha)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_rounded, color: Colores.primario),
              title: const Text('Reprogramar esta sesión'),
              onTap: () => Navigator.pop(ctx, 'mover'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_rounded, color: Colores.rojo),
              title: const Text('Cancelar esta sesión'),
              subtitle: const Text('Se agrega una sesión al final del plan'),
              onTap: () => Navigator.pop(ctx, 'cancelar'),
            ),
          ],
        ),
      ),
    );
    if (accion == null || !context.mounted) return;
    if (accion == 'cancelar') {
      await nube.guardarAgenda(paciente.id, a.conCambio(s.original, null));
      await alGuardar();
      return;
    }
    final dia = await showDatePicker(
      context: context,
      initialDate: s.fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Nueva fecha',
    );
    if (dia == null || !context.mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.fecha.hour, minute: s.fecha.minute),
      helpText: 'Nueva hora',
    );
    if (hora == null) return;
    final nueva = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    await nube.guardarAgenda(paciente.id, a.conCambio(s.original, nueva));
    await alGuardar();
  }

  @override
  Widget build(BuildContext context) {
    final a = agenda;
    if (a == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconoChip(icono: Icons.event_note_rounded, tamano: 72),
              const SizedBox(height: 14),
              const Text('Sin sesiones programadas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Define qué días y a qué hora hace el paciente su rehabilitación y cuántas sesiones son.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colores.textoSuave)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _editar(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Programar sesiones'),
              ),
            ],
          ),
        ),
      );
    }
    final c = Cumplimiento(a, sesiones);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconoChip(icono: Icons.event_repeat_rounded, tamano: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.totalSesiones} sesiones', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Cada ${a.textoDias} · desde ${soloFecha(a.inicio)}',
                            style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (c.realizadas > 0) Expanded(flex: c.realizadas, child: Container(color: Colores.verde)),
                      if (c.perdidas > 0) Expanded(flex: c.perdidas, child: Container(color: Colores.rojo)),
                      if (c.faltan > 0) Expanded(flex: c.faltan, child: Container(color: Colores.azulSuave)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${c.realizadas} realizadas', style: const TextStyle(color: Colores.verde, fontWeight: FontWeight.w600)),
                  Text('${c.perdidas} no asistió', style: const TextStyle(color: Colores.rojo, fontWeight: FontWeight.w600)),
                  Text('${c.faltan} faltan', style: const TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _editar(context),
          icon: const Icon(Icons.edit_calendar_rounded),
          label: const Text('Editar programación'),
        ),
        const SizedBox(height: 16),
        const Text('Toca una sesión pendiente para reprogramarla o cancelarla',
            style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
        const SizedBox(height: 8),
        for (var i = 0; i < c.lista.length; i++) _fila(context, i + 1, c.lista[i].$1, c.lista[i].$2),
      ],
    );
  }

  Widget _fila(BuildContext context, int n, SesionProgramada s, EstadoProgramada e) {
    final (color, icono, texto) = estiloProgramada(e);
    final editable = e == EstadoProgramada.pendiente || e == EstadoProgramada.hoy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: editable ? () => _reprogramar(context, s) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: decoracionTarjeta().copyWith(borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$n', style: const TextStyle(color: Colores.textoSuave, fontWeight: FontWeight.w700)),
              ),
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fechaSesion(s.fecha), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (s.reprogramada)
                      Text('Reprogramada (era ${fechaSesion(s.original)})',
                          style: const TextStyle(color: Colores.textoSuave, fontSize: 11)),
                  ],
                ),
              ),
              Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              if (editable) const Icon(Icons.chevron_right_rounded, color: Colores.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

// Crear o editar la programación
class EditarAgendaPantalla extends StatefulWidget {
  final Cuenta paciente;
  final Agenda? agenda;

  const EditarAgendaPantalla({super.key, required this.paciente, required this.agenda});

  @override
  State<EditarAgendaPantalla> createState() => _EditarAgendaPantallaState();
}

class _EditarAgendaPantallaState extends State<EditarAgendaPantalla> {
  late final Set<int> _dias = {...?widget.agenda?.dias};
  late TimeOfDay _hora = widget.agenda == null
      ? const TimeOfDay(hour: 11, minute: 0)
      : TimeOfDay(hour: widget.agenda!.hora, minute: widget.agenda!.minuto);
  late DateTime _inicio = widget.agenda?.inicio ?? DateTime.now();
  late int _total = widget.agenda?.totalSesiones ?? 12;
  bool _guardando = false;

  Agenda get _borrador => Agenda(
        dias: _dias.toList()..sort(),
        hora: _hora.hour,
        minuto: _hora.minute,
        inicio: DateTime(_inicio.year, _inicio.month, _inicio.day),
        totalSesiones: _total,
        // Al cambiar días u hora, los cambios sueltos anteriores ya no aplican
        cambios: _mismoPatron ? widget.agenda!.cambios : const {},
        actualizada: DateTime.now(),
      );

  bool get _mismoPatron {
    final a = widget.agenda;
    if (a == null) return false;
    return a.hora == _hora.hour &&
        a.minuto == _hora.minute &&
        mismoDia(a.inicio, _inicio) &&
        a.dias.toSet().containsAll(_dias) &&
        _dias.containsAll(a.dias);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await nube.guardarAgenda(widget.paciente.id, _borrador);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final valido = _dias.isNotEmpty;
    final vista = valido ? _borrador.sesiones() : <SesionProgramada>[];
    return Scaffold(
      appBar: AppBar(title: Text(widget.agenda == null ? 'Programar sesiones' : 'Editar programación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(widget.paciente.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Días de la semana', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(Agenda.letrasDias[d - 1]),
                    tooltip: Agenda.nombresDias[d - 1],
                    selected: _dias.contains(d),
                    showCheckmark: false,
                    onSelected: (v) => setState(() => v ? _dias.add(d) : _dias.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: decoracionTarjeta(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded, color: Colores.primario),
                    title: const Text('Hora'),
                    trailing: Text(
                      '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    onTap: () async {
                      final h = await showTimePicker(context: context, initialTime: _hora);
                      if (h != null) setState(() => _hora = h);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_rounded, color: Colores.primario),
                    title: const Text('Desde'),
                    trailing: Text(soloFecha(_inicio), style: const TextStyle(fontWeight: FontWeight.w800)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _inicio,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _inicio = d);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.format_list_numbered_rounded, color: Colores.primario),
                    title: const Text('Número de sesiones'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _total = (_total - 1).clamp(1, 60)),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Text('$_total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        IconButton(
                          onPressed: () => setState(() => _total = (_total + 1).clamp(1, 60)),
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colores.primario),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (valido) ...[
              Text('Cada ${_borrador.textoDias}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Primera: ${fechaSesion(vista.first.fecha)} · Última: ${fechaSesion(vista.last.fecha)}',
                  style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
              if (widget.agenda != null && !_mismoPatron && widget.agenda!.cambios.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Al cambiar días, hora o fecha de inicio se borran las sesiones reprogramadas sueltas.',
                      style: TextStyle(color: Colores.amarillo, fontSize: 12)),
                ),
            ] else
              const Text('Elige al menos un día', style: TextStyle(color: Colores.rojo)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: !valido || _guardando ? null : _guardar,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar programación'),
            ),
          ],
        ),
      ),
    );
  }
}

// Paciente: próxima sesión y avance del plan
class TarjetaProximaSesion extends StatefulWidget {
  final Cuenta paciente;

  const TarjetaProximaSesion({super.key, required this.paciente});

  @override
  State<TarjetaProximaSesion> createState() => _TarjetaProximaSesionState();
}

class _TarjetaProximaSesionState extends State<TarjetaProximaSesion> {
  Cumplimiento? _c;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final a = await nube.agenda(widget.paciente.id);
    final s = await nube.sesionesRehab(widget.paciente.id);
    if (!mounted) return;
    setState(() {
      _c = a == null ? null : Cumplimiento(a, s);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
    final c = _c;
    final p = c?.proxima;
    final hoy = p != null && mismoDia(p.fecha, DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta().copyWith(
        border: Border.all(color: hoy ? Colores.primario : Colores.borde, width: hoy ? 2 : 1),
      ),
      child: Row(
        children: [
          IconoChip(icono: hoy ? Icons.today_rounded : Icons.event_rounded, tamano: 48),
          const SizedBox(width: 14),
          Expanded(
            child: c == null
                ? const Text('Tu fisioterapeuta aún no ha programado tus sesiones',
                    style: TextStyle(color: Colores.textoSuave))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p == null ? 'Plan terminado' : (hoy ? 'Hoy tienes sesión' : 'Próxima sesión'),
                        style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
                      ),
                      Text(
                        p == null ? '${c.realizadas} de ${c.total} sesiones realizadas' : fechaSesion(p.fecha),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      if (p != null)
                        Text('Sesión ${c.numeroProxima} de ${c.total} · llevas ${c.realizadas} realizadas',
                            style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
