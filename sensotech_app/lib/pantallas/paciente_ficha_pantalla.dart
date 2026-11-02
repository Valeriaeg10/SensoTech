import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../modelos/agenda.dart';
import '../modelos/cuenta.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ejercicios.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';
import '../servicios/informe_pdf.dart';
import '../servicios/nube.dart';
import '../servicios/resumen_paciente.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/animacion_ejercicio.dart';
import '../widgets/encuesta_dolor.dart';
import '../widgets/formulario_ficha.dart';
import '../widgets/grafica_dolor.dart';
import '../widgets/grafica_rango.dart';
import '../widgets/icono_chip.dart';
import 'agenda_pantalla.dart';
import 'historial_pantalla.dart';

// Expediente del paciente para el fisio (solo rehabilitación: prevención es privada del paciente)
class PacienteFichaPantalla extends StatefulWidget {
  final ResumenPaciente resumen;
  final Cuenta fisio;

  const PacienteFichaPantalla({super.key, required this.resumen, required this.fisio});

  @override
  State<PacienteFichaPantalla> createState() => _PacienteFichaPantallaState();
}

class _PacienteFichaPantallaState extends State<PacienteFichaPantalla> {
  FichaClinica? _ficha;
  List<NotaEvolucion> _notas = [];
  List<SesionRehab> _sesiones = [];
  Rutina? _rutina;
  Agenda? _agenda;
  bool _cargando = true;

  Cuenta get _p => widget.resumen.cuenta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final ficha = await nube.ficha(_p.id);
    final notas = await nube.notas(_p.id);
    final sesiones = await nube.sesionesRehab(_p.id);
    final rutina = await nube.rutina(_p.id);
    final agenda = await nube.agenda(_p.id);
    if (!mounted) return;
    setState(() {
      _ficha = ficha;
      _notas = notas;
      _sesiones = sesiones;
      _rutina = rutina;
      _agenda = agenda;
      _cargando = false;
    });
  }

  void _abrirInforme() {
    final informe = InformePdf(
      paciente: _p,
      fisio: widget.fisio,
      ficha: _ficha,
      rutina: _rutina,
      sesiones: _sesiones,
      notas: _notas,
      agenda: _agenda,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Informe PDF')),
          body: PdfPreview(
            build: informe.generar,
            pdfFileName: informe.nombreArchivo,
            canChangeOrientation: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_p.nombre),
          actions: [
            IconButton(
              tooltip: 'Informe PDF',
              onPressed: _cargando ? null : _abrirInforme,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumen'),
              Tab(icon: Icon(Icons.event_note_rounded), text: 'Agenda'),
              Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Historia clínica'),
              Tab(icon: Icon(Icons.show_chart_rounded), text: 'Progreso'),
              Tab(icon: Icon(Icons.edit_note_rounded), text: 'Evolución'),
              Tab(icon: Icon(Icons.fitness_center_rounded), text: 'Rutina'),
            ],
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _Resumen(p: _p, ficha: _ficha, sesiones: _sesiones, rutina: _rutina, agenda: _agenda, alInforme: _abrirInforme),
                  PestanaAgenda(paciente: _p, agenda: _agenda, sesiones: _sesiones, alGuardar: _cargar),
                  _Historia(p: _p, ficha: _ficha, alGuardar: _cargar),
                  _Progreso(sesiones: _sesiones),
                  _Evolucion(p: _p, fisio: widget.fisio, sesiones: _sesiones, notas: _notas, alCambiar: _cargar),
                  EditorRutina(paciente: _p, rutina: _rutina, sesiones: _sesiones, alGuardar: _cargar),
                ],
              ),
      ),
    );
  }
}

Widget _titulo(String t, {String? sub}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (sub != null) Text(sub, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
        ],
      ),
    );

Widget _dato(IconData i, String titulo, String valor, {Color? color}) => Container(
      padding: const EdgeInsets.all(12),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 20, color: color ?? Colores.primario),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );

// ---------------- Resumen ----------------
class _Resumen extends StatelessWidget {
  final Cuenta p;
  final FichaClinica? ficha;
  final List<SesionRehab> sesiones;
  final Rutina? rutina;
  final Agenda? agenda;
  final VoidCallback alInforme;

  const _Resumen({
    required this.p,
    required this.ficha,
    required this.sesiones,
    required this.rutina,
    required this.agenda,
    required this.alInforme,
  });

  // Alertas clínicas sencillas para el fisio
  List<String> _alertas() {
    final a = <String>[];
    if (agenda == null) a.add('No tiene sesiones programadas: prográmalas en la pestaña Agenda.');
    if (agenda != null) {
      final c = Cumplimiento(agenda!, sesiones);
      if (c.perdidasRecientes > 0) {
        a.add('No asistió a ${c.perdidasRecientes} de sus últimas sesiones programadas.');
      }
    }
    if (sesiones.isEmpty) return [...a, 'El paciente aún no ha hecho sesiones de rehabilitación.'];
    final u = sesiones.last;
    if (u.dolorAntes != null && u.dolorDespues != null && u.dolorDespues! > u.dolorAntes!) {
      a.add('En la última sesión el dolor aumentó (${u.dolorAntes} → ${u.dolorDespues}).');
    }
    if (u.dolorDespues != null && u.dolorDespues! >= 7) a.add('Dolor intenso al terminar la última sesión.');
    final ultimas = sesiones.length >= 3 ? sesiones.sublist(sesiones.length - 3) : sesiones;
    final incompletas = ultimas.where((s) => !s.completa).length;
    if (incompletas >= 2) a.add('$incompletas de las últimas ${ultimas.length} sesiones quedaron incompletas.');
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final f = ficha;
    final completas = sesiones.where((s) => s.completa).toList();
    final ultimaEva = sesiones.reversed.map((s) => s.dolorAntes).whereType<int>().firstOrNull;
    final alertas = _alertas();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colores.azulSuave,
                child: Text(p.iniciales,
                    style: const TextStyle(color: Colores.primario, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    if (f != null)
                      Text(
                        '${f.tipoDocumento} ${f.numeroDocumento}${f.edad == null ? '' : ' · ${f.edad} años'}'
                        '${f.sexo.isEmpty ? '' : ' · ${f.sexo}'}',
                        style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
                      ),
                    if (f != null && f.ocupacion.isNotEmpty)
                      Text(f.ocupacion, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      f == null
                          ? 'Sin historia clínica'
                          : '${f.diagnostico} (${f.codigoCie10}) · mano ${f.manoAfectada.toLowerCase()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (p.demo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colores.azulSuave, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Demo', style: TextStyle(fontSize: 11, color: Colores.primario)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _dato(
                Icons.event_available_rounded,
                'Plan',
                agenda == null
                    ? '${sesiones.length} hechas'
                    : '${Cumplimiento(agenda!, sesiones).realizadas}/${agenda!.totalSesiones}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dato(Icons.task_alt_rounded, 'Completas',
                  sesiones.isEmpty ? '—' : '${(completas.length * 100 / sesiones.length).round()} %'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dato(
                EncuestaDolor.cara(ultimaEva ?? 0),
                'Último EVA',
                ultimaEva == null ? '—' : '$ultimaEva/10',
                color: ultimaEva == null ? null : EncuestaDolor.color(ultimaEva),
              ),
            ),
          ],
        ),
        if (alertas.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colores.amarillo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colores.amarillo.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notification_important_outlined, color: Colores.amarillo),
                    SizedBox(width: 8),
                    Text('Para revisar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                for (final a in alertas)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $a', style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _titulo('Rango articular', sub: 'Primera sesión completa contra la última'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: completas.isEmpty
              ? const Text('Sin sesiones completas todavía', style: TextStyle(color: Colores.textoSuave))
              : Column(
                  children: [
                    for (final t in TipoEjercicio.values) ...[
                      BarraRango(
                        tipo: t,
                        base: completas.first.maximo(t),
                        actual: completas.last.maximo(t),
                        comparar: completas.length > 1,
                      ),
                      const SizedBox(height: 14),
                    ],
                    const LeyendaRango(),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: alInforme,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Generar informe para la historia clínica'),
        ),
      ],
    );
  }
}

// ---------------- Historia clínica ----------------
class _Historia extends StatelessWidget {
  final Cuenta p;
  final FichaClinica? ficha;
  final Future<void> Function() alGuardar;

  const _Historia({required this.p, required this.ficha, required this.alGuardar});

  Future<void> _editar(BuildContext context) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditarFichaPantalla(ficha: ficha ?? FichaClinica(pacienteId: p.id))),
    );
    if (guardado == true) await alGuardar();
  }

  Widget _fila(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(a, style: const TextStyle(color: Colores.textoSuave, fontSize: 13))),
            Expanded(
              child: Text(b.trim().isEmpty ? '—' : b, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _bloque(IconData i, String titulo, List<Widget> filas) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: decoracionTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconoChip(icono: i, tamano: 32),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            ...filas,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = ficha;
    if (f == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconoChip(icono: Icons.assignment_late_outlined, tamano: 72),
              const SizedBox(height: 14),
              const Text('Sin historia clínica', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _editar(context),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Diligenciar historia'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _bloque(Icons.badge_outlined, 'Identificación', [
          _fila('Nombre', p.nombre),
          _fila('Documento', '${f.tipoDocumento} ${f.numeroDocumento}'),
          _fila('Nacimiento', f.fechaNacimiento == null ? '' : '${soloFecha(f.fechaNacimiento!)} (${f.edad} años)'),
          _fila('Sexo', f.sexo),
          _fila('Estado civil', f.estadoCivil),
          _fila('Ocupación', f.ocupacion),
          _fila('Teléfono', f.telefono),
          _fila('Dirección', f.direccion),
          _fila('EPS', f.eps),
          _fila('Acompañante', f.textoAcompanante),
          _fila('Correo (usuario)', p.correo),
          _fila('Mano dominante', f.manoDominante),
          _fila('Mano afectada', f.manoAfectada),
        ]),
        _bloque(Icons.assignment_ind_outlined, 'Valoración inicial', [
          _fila('Fecha', f.fechaValoracion == null ? '' : soloFecha(f.fechaValoracion!)),
          _fila('Motivo de consulta', f.motivoConsulta),
          _fila('Diagnóstico', '${f.diagnostico}${f.codigoCie10.isEmpty ? '' : ' (CIE-10 ${f.codigoCie10})'}'),
          _fila('Antecedentes', f.antecedentes),
          _fila('Dolor inicial (EVA)', f.dolorInicial == null ? '' : '${f.dolorInicial}/10'),
          _fila('Phalen', f.phalen.texto),
          _fila('Tinel', f.tinel.texto),
          _fila('Durkan', f.durkan.texto),
          _fila('BCTQ (severidad)', f.bctq == null ? '' : f.bctq!.toStringAsFixed(1)),
          const Divider(height: 18),
          const Text('Goniometría inicial', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          for (final t in TipoEjercicio.values)
            _fila(t.texto, f.goniometria[t] == null ? '' : '${f.goniometria[t]!.round()}° (normal ${rangoReferencia[t]!.round()}°)'),
          const Divider(height: 18),
          _fila('Objetivos', f.objetivos),
        ]),
        FilledButton.icon(
          onPressed: () => _editar(context),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Editar historia clínica'),
        ),
      ],
    );
  }
}

// Pantalla para editar la historia clínica
class EditarFichaPantalla extends StatefulWidget {
  final FichaClinica ficha;

  const EditarFichaPantalla({super.key, required this.ficha});

  @override
  State<EditarFichaPantalla> createState() => _EditarFichaPantallaState();
}

class _EditarFichaPantallaState extends State<EditarFichaPantalla> {
  final _form = GlobalKey<FormState>();
  final _ficha = GlobalKey<FormularioFichaState>();
  String? _error;
  bool _guardando = false;

  Future<void> _guardar() async {
    final valido = _form.currentState!.validate();
    final falta = _ficha.currentState!.faltantes();
    if (!valido || falta != null) {
      setState(() => _error = falta ?? 'Revisa los campos marcados');
      return;
    }
    setState(() => _guardando = true);
    await nube.guardarFicha(_ficha.currentState!.construir(widget.ficha.pacienteId));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historia clínica')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              FormularioFicha(key: _ficha, ficha: widget.ficha),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colores.rojo)),
                ),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Progreso ----------------
class _Progreso extends StatefulWidget {
  final List<SesionRehab> sesiones;
  const _Progreso({required this.sesiones});

  @override
  State<_Progreso> createState() => _ProgresoState();
}

class _ProgresoState extends State<_Progreso> {
  final Set<TipoEjercicio> _visibles = TipoEjercicio.values.toSet();

  @override
  Widget build(BuildContext context) {
    final s = widget.sesiones;
    if (s.isEmpty) {
      return const Center(child: Text('Sin sesiones de rehabilitación todavía', style: TextStyle(color: Colores.textoSuave)));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _titulo('Rango articular', sub: 'Ángulo máximo por sesión (eje horizontal: número de sesión)'),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
          decoration: decoracionTarjeta(),
          child: Column(
            children: [
              GraficaRango(sesiones: s, visibles: Set.of(_visibles)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in TipoEjercicio.values)
                    FilterChip(
                      label: Text(t.texto, style: const TextStyle(fontSize: 12)),
                      avatar: CircleAvatar(backgroundColor: coloresMovimiento[t], radius: 5),
                      selected: _visibles.contains(t),
                      showCheckmark: false,
                      onSelected: (v) => setState(() => v ? _visibles.add(t) : _visibles.remove(t)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _titulo('Dolor', sub: 'Escala visual analógica antes y después de cada sesión'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: decoracionTarjeta(),
          child: GraficaDolor(sesiones: s),
        ),
      ],
    );
  }
}

// ---------------- Evolución: sesiones y notas del fisio ----------------
class _Evolucion extends StatelessWidget {
  final Cuenta p;
  final Cuenta fisio;
  final List<SesionRehab> sesiones;
  final List<NotaEvolucion> notas;
  final Future<void> Function() alCambiar;

  const _Evolucion({
    required this.p,
    required this.fisio,
    required this.sesiones,
    required this.notas,
    required this.alCambiar,
  });

  Future<void> _nuevaNota(BuildContext context) async {
    final texto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota de evolución'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fisio.nombre} · TP ${fisio.tarjetaProfesional ?? '—'}\n${fechaHora(DateTime.now())}',
                style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: texto,
              maxLines: 6,
              minLines: 4,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Evolución, hallazgos, conducta y plan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final t = texto.text.trim();
    texto.dispose();
    if (ok != true || t.isEmpty) return;
    await nube.agregarNota(NotaEvolucion(
      pacienteId: p.id,
      fecha: DateTime.now(),
      texto: t,
      autor: fisio.nombre,
      tarjeta: fisio.tarjetaProfesional ?? '',
    ));
    await alCambiar();
  }

  @override
  Widget build(BuildContext context) {
    // Sesiones y notas juntas, de la más reciente a la más vieja
    final items = <(DateTime, Widget)>[
      for (var i = 0; i < sesiones.length; i++)
        (
          sesiones[i].fecha,
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colores.fondo,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => _DetalleSesion(s: sesiones[i], anterior: i == 0 ? null : sesiones[i - 1]),
            ),
            child: FilaSesionRehab(sesion: sesiones[i]),
          ),
        ),
      for (final n in notas) (n.fecha, _tarjetaNota(n)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: () => _nuevaNota(context),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Agregar nota de evolución'),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Text('Sin registros todavía', style: TextStyle(color: Colores.textoSuave)),
        for (final it in items) ...[it.$2, const SizedBox(height: 10)],
      ],
    );
  }

  Widget _tarjetaNota(NotaEvolucion n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: decoracionTarjeta().copyWith(color: const Color(0xFFF9FBFE)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconoChip(icono: Icons.edit_note_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nota · ${fechaHora(n.fecha)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(n.texto, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('${n.autor}${n.tarjeta.isEmpty ? '' : ' · TP ${n.tarjeta}'}',
                      style: const TextStyle(color: Colores.textoSuave, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
}

// Detalle de una sesión: rango articular contra la anterior, dolor y ejercicios hechos
class _DetalleSesion extends StatelessWidget {
  final SesionRehab s;
  final SesionRehab? anterior;
  const _DetalleSesion({required this.s, this.anterior});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesión del ${fechaHora(s.fecha)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(s.completa ? 'Completa' : 'Incompleta', style: const TextStyle(color: Colores.textoSuave)),
            const SizedBox(height: 14),
            for (final t in TipoEjercicio.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: coloresMovimiento[t], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.texto)),
                    Text('${s.maximo(t).round()}°', style: const TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(
                      width: 56,
                      child: Builder(builder: (_) {
                        final a = anterior;
                        if (a == null) return const Text('—', textAlign: TextAlign.right);
                        final d = s.maximo(t) - a.maximo(t);
                        return Text(
                          '${d >= 0 ? '+' : ''}${d.round()}°',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: d >= 0 ? Colores.verde : Colores.rojo, fontWeight: FontWeight.w700),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            const Text('Diferencia contra la sesión anterior', style: TextStyle(color: Colores.textoSuave, fontSize: 11)),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _eva('Dolor antes', s.dolorAntes)),
                const Icon(Icons.arrow_forward_rounded, color: Colores.textoSuave),
                Expanded(child: _eva('Dolor después', s.dolorDespues)),
              ],
            ),
            if (s.realizados.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Ejercicios realizados', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final e in s.realizados)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('• ${e.def.nombre}: ${e.series} × ${e.repeticiones}, meta ${e.textoMeta.toLowerCase()}',
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eva(String t, int? v) => Column(
        children: [
          Text(t, style: const TextStyle(color: Colores.textoSuave, fontSize: 12)),
          if (v == null)
            const Text('—')
          else ...[
            Icon(EncuestaDolor.cara(v), color: EncuestaDolor.color(v), size: 30),
            Text('$v/10', style: TextStyle(fontWeight: FontWeight.w800, color: EncuestaDolor.color(v))),
          ],
        ],
      );
}

// ---------------- Rutina ----------------
class EditorRutina extends StatefulWidget {
  final Cuenta paciente;
  final Rutina? rutina;
  final List<SesionRehab> sesiones;
  final Future<void> Function() alGuardar;

  const EditorRutina({
    super.key,
    required this.paciente,
    required this.rutina,
    required this.sesiones,
    required this.alGuardar,
  });

  @override
  State<EditorRutina> createState() => _EditorRutinaState();
}

class _EditorRutinaState extends State<EditorRutina> {
  // Por cada ejercicio de rehabilitación: incluido o no, y su configuración
  late final Map<IdEjercicio, EjercicioRutina> _config;
  late final Set<IdEjercicio> _incluidos;
  late int _descanso;
  late final TextEditingController _nota;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final base = widget.rutina ?? Rutina.predefinida();
    _config = {
      for (final id in ejerciciosRehab)
        id: base.ejercicios.where((e) => e.id == id).firstOrNull ??
            EjercicioRutina(id: id, series: catalogo[id]!.seriesBase, repeticiones: catalogo[id]!.repsBase),
    };
    _incluidos = base.ejercicios.map((e) => e.id).where(ejerciciosRehab.contains).toSet();
    _descanso = base.descanso;
    _nota = TextEditingController(text: base.nota ?? '');
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  // Meta progresiva que tendría hoy (para mostrarla al fisio)
  double _progresivaHoy(DefEjercicio d) {
    final completas = widget.sesiones.where((s) => s.completa).toList();
    return metaProgresiva(d, completas.isEmpty ? null : completas.last.maximos);
  }

  void _cambiar(IdEjercicio id, {int? series, int? reps, double? meta, bool quitarMeta = false}) {
    final e = _config[id]!;
    setState(() => _config[id] = EjercicioRutina(
          id: id,
          series: (series ?? e.series).clamp(1, 10),
          repeticiones: (reps ?? e.repeticiones).clamp(1, 30),
          meta: quitarMeta ? null : (meta ?? e.meta),
        ));
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await nube.guardarRutina(
      widget.paciente.id,
      Rutina(
        ejercicios: [for (final id in ejerciciosRehab) if (_incluidos.contains(id)) _config[id]!],
        descanso: _descanso,
        actualizada: DateTime.now(),
        nota: _nota.text.trim(),
      ),
    );
    await widget.alGuardar();
    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rutina guardada para ${widget.paciente.nombre}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _titulo('Rutina de rehabilitación',
            sub: widget.rutina == null
                ? 'El paciente usa la rutina predefinida. Ajústala y guarda.'
                : 'Actualizada el ${fechaHora(widget.rutina!.actualizada)}'),
        for (final id in ejerciciosRehab) ...[
          _tarjetaEjercicio(catalogo[id]!),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: decoracionTarjeta(),
          child: _contador('Descanso entre series (s)', _descanso,
              (v) => setState(() => _descanso = v.clamp(10, 120)), paso: 10),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nota,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Indicaciones para el paciente (opcional)',
            filled: true,
            fillColor: Colores.blanco,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _guardando || _incluidos.isEmpty ? null : _guardar,
          icon: const Icon(Icons.send_rounded),
          label: Text(_guardando ? 'Guardando…' : 'Guardar y enviar al paciente'),
        ),
      ],
    );
  }

  Widget _tarjetaEjercicio(DefEjercicio d) {
    final e = _config[d.id]!;
    final incluido = _incluidos.contains(d.id);
    final minimo = d.id == IdEjercicio.r3Pendulo ? 5.0 : 10.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: AnimacionEjercicio(demo: d.demo, titulo: d.nombre, descripcion: d.instruccion),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(d.mecanica, style: const TextStyle(color: Colores.textoSuave, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: incluido,
                onChanged: (v) => setState(() => v ? _incluidos.add(d.id) : _incluidos.remove(d.id)),
              ),
            ],
          ),
          if (incluido) ...[
            const Divider(height: 18),
            _contador('Series', e.series, (v) => _cambiar(d.id, series: v)),
            _contador('Repeticiones', e.repeticiones, (v) => _cambiar(d.id, reps: v)),
            const SizedBox(height: 6),
            const Text('Meta (ángulo objetivo)', style: TextStyle(color: Colores.textoSuave)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Progresiva'), icon: Icon(Icons.trending_up_rounded)),
                  ButtonSegment(value: false, label: Text('Fija'), icon: Icon(Icons.push_pin_outlined)),
                ],
                selected: {e.meta == null},
                showSelectedIcon: false,
                onSelectionChanged: (s) => s.first
                    ? _cambiar(d.id, quitarMeta: true)
                    : _cambiar(d.id, meta: _progresivaHoy(d).clamp(minimo, d.metaMax).roundToDouble()),
              ),
            ),
            const SizedBox(height: 6),
            if (e.meta == null)
              Text(
                'Último máximo + 5°, sin pasar ${d.metaMax.round()}°. Hoy sería ${_progresivaHoy(d).round()}°.',
                style: const TextStyle(color: Colores.textoSuave, fontSize: 12),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: e.meta!.clamp(minimo, d.metaMax),
                      min: minimo,
                      max: d.metaMax,
                      divisions: (d.metaMax - minimo).round(),
                      label: '${e.meta!.round()}°',
                      onChanged: (v) => _cambiar(d.id, meta: v.roundToDouble()),
                    ),
                  ),
                  Text('${e.meta!.round()}°', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _contador(String t, int v, ValueChanged<int> cambio, {int paso = 1}) {
    return Row(
      children: [
        Expanded(child: Text(t, style: const TextStyle(color: Colores.textoSuave))),
        IconButton(onPressed: () => cambio(v - paso), icon: const Icon(Icons.remove_circle_outline_rounded)),
        SizedBox(
          width: 36,
          child: Text('$v', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          onPressed: () => cambio(v + paso),
          icon: const Icon(Icons.add_circle_outline_rounded, color: Colores.primario),
        ),
      ],
    );
  }
}
