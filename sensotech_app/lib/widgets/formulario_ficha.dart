import 'package:flutter/material.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import 'encuesta_dolor.dart';
import 'icono_chip.dart';

// Historia clínica: identificación (Res. 1995/1999 art. 9) y valoración inicial de fisioterapia.
// Se usa al agregar un paciente y al editar su historia.
class FormularioFicha extends StatefulWidget {
  final FichaClinica ficha;

  const FormularioFicha({super.key, required this.ficha});

  @override
  State<FormularioFicha> createState() => FormularioFichaState();
}

class FormularioFichaState extends State<FormularioFicha> {
  static const tiposDocumento = {
    'CC': 'Cédula de ciudadanía',
    'TI': 'Tarjeta de identidad',
    'CE': 'Cédula de extranjería',
    'PA': 'Pasaporte',
    'PPT': 'Permiso por protección temporal',
  };
  static const sexos = ['Femenino', 'Masculino', 'Intersexual'];
  static const estadosCiviles = ['Soltero(a)', 'Casado(a)', 'Unión libre', 'Separado(a) / Divorciado(a)', 'Viudo(a)'];

  late final f = widget.ficha;
  late String _tipoDoc = tiposDocumento.containsKey(f.tipoDocumento) ? f.tipoDocumento : 'CC';
  late final _numero = TextEditingController(text: f.numeroDocumento);
  late DateTime? _nacimiento = f.fechaNacimiento;
  late String? _sexo = sexos.contains(f.sexo) ? f.sexo : null;
  late String? _estadoCivil = estadosCiviles.contains(f.estadoCivil) ? f.estadoCivil : null;
  late final _ocupacion = TextEditingController(text: f.ocupacion);
  late final _telefono = TextEditingController(text: f.telefono);
  late final _direccion = TextEditingController(text: f.direccion);
  late final _eps = TextEditingController(text: f.eps);
  late final _acompanante = TextEditingController(text: f.acompanante);
  late final _acompTelefono = TextEditingController(text: f.acompananteTelefono);
  late final _acompParentesco = TextEditingController(text: f.acompananteParentesco);
  late String _manoDominante = f.manoDominante.isEmpty ? 'Derecha' : f.manoDominante;
  late String _manoAfectada = f.manoAfectada.isEmpty ? 'Derecha' : f.manoAfectada;
  late String _manoBrazalete = f.manoBrazalete == 'Izquierda' ? 'Izquierda' : 'Derecha';

  late DateTime _fechaValoracion = f.fechaValoracion ?? DateTime.now();
  late final _motivo = TextEditingController(text: f.motivoConsulta);
  late final _diagnostico = TextEditingController(text: f.diagnostico);
  late final _cie10 = TextEditingController(text: f.codigoCie10);
  late final _antecedentes = TextEditingController(text: f.antecedentes);
  late int? _dolor = f.dolorInicial;
  late final _gonio = {
    for (final t in TipoEjercicio.values)
      t: TextEditingController(text: f.goniometria[t] == null ? '' : f.goniometria[t]!.round().toString()),
  };
  late ResultadoPrueba _phalen = f.phalen;
  late ResultadoPrueba _tinel = f.tinel;
  late ResultadoPrueba _durkan = f.durkan;
  late final _bctq = TextEditingController(text: f.bctq?.toStringAsFixed(1) ?? '');
  late final _objetivos = TextEditingController(text: f.objetivos);

  @override
  void dispose() {
    for (final c in [
      _numero, _ocupacion, _telefono, _direccion, _eps, _acompanante, _acompTelefono, _acompParentesco, _motivo, _diagnostico, _cie10,
      _antecedentes, _bctq, _objetivos, ..._gonio.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Lee lo escrito (llamar después de validar el Form que lo contiene)
  FichaClinica construir(String pacienteId) {
    final bctq = double.tryParse(_bctq.text.replaceAll(',', '.'));
    return FichaClinica(
      pacienteId: pacienteId,
      tipoDocumento: _tipoDoc,
      numeroDocumento: _numero.text.trim(),
      fechaNacimiento: _nacimiento,
      sexo: _sexo ?? '',
      estadoCivil: _estadoCivil ?? '',
      ocupacion: _ocupacion.text.trim(),
      telefono: _telefono.text.trim(),
      direccion: _direccion.text.trim(),
      eps: _eps.text.trim(),
      acompanante: _acompanante.text.trim(),
      acompananteTelefono: _acompTelefono.text.trim(),
      acompananteParentesco: _acompParentesco.text.trim(),
      manoDominante: _manoDominante,
      manoAfectada: _manoAfectada,
      manoBrazalete: _manoAfectada == 'Bilateral' ? _manoBrazalete : _manoAfectada,
      fechaValoracion: _fechaValoracion,
      motivoConsulta: _motivo.text.trim(),
      diagnostico: _diagnostico.text.trim(),
      codigoCie10: _cie10.text.trim().toUpperCase(),
      antecedentes: _antecedentes.text.trim(),
      dolorInicial: _dolor,
      goniometria: {
        for (final e in _gonio.entries)
          if (double.tryParse(e.value.text.trim()) != null) e.key: double.parse(e.value.text.trim()),
      },
      phalen: _phalen,
      tinel: _tinel,
      durkan: _durkan,
      bctq: bctq,
      objetivos: _objetivos.text.trim(),
    );
  }

  // Lo que falta y el Form no puede validar solo
  String? faltantes() {
    if (_nacimiento == null) return 'Falta la fecha de nacimiento';
    if (_sexo == null) return 'Falta el sexo';
    return null;
  }

  InputDecoration _deco(String etiqueta, {String? ayuda}) => InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        filled: true,
        fillColor: Colores.blanco,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colores.borde),
        ),
      );

  Widget _texto(TextEditingController c, String etiqueta,
      {bool obligatorio = false, int lineas = 1, TextInputType? teclado, String? ayuda}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: lineas,
        minLines: 1,
        keyboardType: teclado,
        textCapitalization: TextCapitalization.sentences,
        decoration: _deco(obligatorio ? '$etiqueta *' : etiqueta, ayuda: ayuda),
        validator: obligatorio ? (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null : null,
      ),
    );
  }

  Widget _lista(String etiqueta, String? valor, List<String> opciones, ValueChanged<String?> cambio,
      {Map<String, String>? textos, bool obligatorio = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: valor,
        isExpanded: true,
        decoration: _deco(obligatorio ? '$etiqueta *' : etiqueta),
        items: [for (final o in opciones) DropdownMenuItem(value: o, child: Text(textos?[o] ?? o))],
        onChanged: cambio,
        validator: obligatorio ? (v) => v == null ? 'Obligatorio' : null : null,
      ),
    );
  }

  Widget _segmentos(String etiqueta, String valor, List<String> opciones, ValueChanged<String> cambio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(color: Colores.textoSuave, fontSize: 13)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [for (final o in opciones) ButtonSegment(value: o, label: Text(o))],
              selected: {valor},
              showSelectedIcon: false,
              onSelectionChanged: (s) => cambio(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prueba(String nombre, String detalle, ResultadoPrueba valor, ValueChanged<ResultadoPrueba> cambio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(detalle, style: const TextStyle(color: Colores.textoSuave, fontSize: 11)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ResultadoPrueba>(
              segments: [for (final r in ResultadoPrueba.values) ButtonSegment(value: r, label: Text(r.texto))],
              selected: {valor},
              showSelectedIcon: false,
              onSelectionChanged: (s) => cambio(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _elegirFecha(DateTime? inicial, {required DateTime primera}) => showDatePicker(
        context: context,
        initialDate: inicial ?? DateTime(1990),
        firstDate: primera,
        lastDate: DateTime.now(),
        helpText: 'Elige la fecha',
      );

  Widget _fecha(String etiqueta, DateTime? valor, VoidCallback alTocar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: _deco(etiqueta).copyWith(suffixIcon: const Icon(Icons.calendar_month_rounded)),
          child: Text(valor == null ? 'Elegir' : soloFecha(valor),
              style: TextStyle(color: valor == null ? Colores.textoSuave : Colores.texto)),
        ),
      ),
    );
  }

  Widget _seccion(IconData icono, String titulo, String sub, List<Widget> hijos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoChip(icono: icono, tamano: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(sub, style: const TextStyle(color: Colores.textoSuave, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...hijos,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final edad = _nacimiento == null ? null : FichaClinica(pacienteId: '', fechaNacimiento: _nacimiento).edad;
    return Column(
      children: [
        _seccion(Icons.badge_outlined, 'Identificación', 'Datos mínimos de la historia clínica', [
          _lista('Tipo de documento', _tipoDoc, tiposDocumento.keys.toList(), (v) => setState(() => _tipoDoc = v!),
              textos: tiposDocumento, obligatorio: true),
          _texto(_numero, 'Número de documento', obligatorio: true, teclado: TextInputType.number),
          _fecha(
            edad == null ? 'Fecha de nacimiento *' : 'Fecha de nacimiento * ($edad años)',
            _nacimiento,
            () async {
              final d = await _elegirFecha(_nacimiento, primera: DateTime(1920));
              if (d != null) setState(() => _nacimiento = d);
            },
          ),
          _lista('Sexo', _sexo, sexos, (v) => setState(() => _sexo = v), obligatorio: true),
          _lista('Estado civil', _estadoCivil, estadosCiviles, (v) => setState(() => _estadoCivil = v)),
          _texto(_ocupacion, 'Ocupación', obligatorio: true, ayuda: 'Importante en el STC: tipo de tarea manual'),
          _texto(_telefono, 'Teléfono', teclado: TextInputType.phone),
          _texto(_direccion, 'Dirección y municipio'),
          _texto(_eps, 'Aseguradora (EPS)'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Acompañante o responsable (si aplica)',
                style: TextStyle(color: Colores.textoSuave, fontSize: 13)),
          ),
          _texto(_acompanante, 'Nombre del acompañante'),
          Row(
            children: [
              Expanded(child: _texto(_acompParentesco, 'Parentesco')),
              const SizedBox(width: 10),
              Expanded(child: _texto(_acompTelefono, 'Teléfono', teclado: TextInputType.phone)),
            ],
          ),
          _segmentos('Mano dominante', _manoDominante, ['Derecha', 'Izquierda', 'Ambidiestro'],
              (v) => setState(() => _manoDominante = v)),
          _segmentos('Mano afectada', _manoAfectada, ['Derecha', 'Izquierda', 'Bilateral'],
              (v) => setState(() => _manoAfectada = v)),
          if (_manoAfectada == 'Bilateral')
            _segmentos('Mano donde usará el brazalete', _manoBrazalete, ['Derecha', 'Izquierda'],
                (v) => setState(() => _manoBrazalete = v)),
        ]),
        _seccion(Icons.assignment_ind_outlined, 'Valoración inicial', 'Evaluación de fisioterapia de ingreso', [
          _fecha('Fecha de la valoración', _fechaValoracion, () async {
            final d = await _elegirFecha(_fechaValoracion, primera: DateTime(2020));
            if (d != null) setState(() => _fechaValoracion = d);
          }),
          _texto(_motivo, 'Motivo de consulta', lineas: 3),
          _texto(_diagnostico, 'Diagnóstico'),
          _texto(_cie10, 'Código CIE-10', ayuda: 'G56.0 = Síndrome del túnel carpiano'),
          _texto(_antecedentes, 'Antecedentes (patológicos, quirúrgicos, ocupacionales)', lineas: 3),
          const SizedBox(height: 4),
          EncuestaDolor(
            pregunta: 'Dolor inicial (EVA)',
            valor: _dolor,
            alCambiar: (v) => setState(() => _dolor = v),
          ),
          const SizedBox(height: 16),
          const Text('Goniometría inicial (grados)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 0,
            children: [
              for (final t in TipoEjercicio.values)
                SizedBox(
                  width: 150,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _gonio[t],
                      keyboardType: TextInputType.number,
                      decoration: _deco(t.texto, ayuda: 'Normal ${rangoReferencia[t]!.round()}°'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return null;
                        final n = double.tryParse(s);
                        if (n == null || n < 0 || n > 90) return 'Entre 0 y 90';
                        return null;
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _prueba('Prueba de Phalen', 'Flexión palmar sostenida 60 s', _phalen, (v) => setState(() => _phalen = v)),
          _prueba('Signo de Tinel', 'Percusión sobre el nervio mediano en el carpo', _tinel,
              (v) => setState(() => _tinel = v)),
          _prueba('Prueba de Durkan', 'Compresión directa del túnel carpiano 30 s', _durkan,
              (v) => setState(() => _durkan = v)),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _bctq,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Cuestionario de Boston (BCTQ), escala de severidad',
                  ayuda: 'Puntaje promedio de 1,0 (sin síntomas) a 5,0 (muy severo)'),
              validator: (v) {
                final s = (v ?? '').trim().replaceAll(',', '.');
                if (s.isEmpty) return null;
                final n = double.tryParse(s);
                if (n == null || n < 1 || n > 5) return 'Entre 1,0 y 5,0';
                return null;
              },
            ),
          ),
          _texto(_objetivos, 'Objetivos del tratamiento', lineas: 3),
        ]),
      ],
    );
  }
}
