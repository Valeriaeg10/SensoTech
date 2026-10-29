import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../modelos/cuenta.dart';
import '../modelos/datos_brazalete.dart';
import '../modelos/ficha_clinica.dart';
import '../modelos/rutina.dart';

// Informe de seguimiento fisioterapéutico (PDF) para anexar a la historia clínica.
// Estructura basada en la Res. 1995 de 1999: identificación, registros con fecha y hora,
// nombre y tarjeta profesional de quien registra, y firma.
class InformePdf {
  final Cuenta paciente;
  final Cuenta fisio;
  final FichaClinica? ficha;
  final Rutina? rutina;
  final List<SesionRehab> sesiones; // de la más vieja a la más reciente
  final List<NotaEvolucion> notas;

  InformePdf({
    required this.paciente,
    required this.fisio,
    required this.ficha,
    required this.rutina,
    required this.sesiones,
    required this.notas,
  });

  String get nombreArchivo {
    final f = DateTime.now();
    final n = paciente.nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return 'Informe_${n}_${f.year}${f.month.toString().padLeft(2, '0')}${f.day.toString().padLeft(2, '0')}.pdf';
  }

  // Las fuentes del PDF (Times) solo traen caracteres latinos: se reemplaza lo demás
  static String _s(String t) {
    const cambios = {'–': '-', '—': '-', '“': '"', '”': '"', '‘': "'", '’': "'", '•': '-', '…': '...', '→': '->'};
    final b = StringBuffer();
    for (final r in t.runes) {
      final c = String.fromCharCode(r);
      if (cambios.containsKey(c)) {
        b.write(cambios[c]);
      } else if (r == 10 || (r >= 32 && r <= 126) || (r >= 160 && r <= 255)) {
        b.write(c);
      }
    }
    return b.toString();
  }

  static String _v(String t) => t.trim().isEmpty ? 'No registrado' : _s(t.trim());
  static String _g(double v) => '${v.round()}°';

  Future<Uint8List> generar(PdfPageFormat formato) async {
    final doc = pw.Document(
      title: 'Informe de seguimiento fisioterapéutico',
      author: _s(fisio.nombre),
      creator: 'SensoTech',
      theme: pw.ThemeData.withFont(
        base: pw.Font.times(),
        bold: pw.Font.timesBold(),
        italic: pw.Font.timesItalic(),
        boldItalic: pw.Font.timesBoldItalic(),
      ),
    );
    final generado = fechaHora(DateTime.now());
    final f = ficha;

    doc.addPage(
      pw.MultiPage(
        pageFormat: formato,
        margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
        maxPages: 60,
        header: (ctx) => _encabezado(ctx),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Generado el $generado con SensoTech  -  Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (ctx) => [
          pw.Center(
            child: pw.Text('INFORME DE SEGUIMIENTO FISIOTERAPÉUTICO',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'Programa de rehabilitación del síndrome del túnel carpiano con dispositivo SensoTech',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 14),

          // 1. Identificación
          _titulo('1. Datos de identificación del paciente'),
          _pares([
            ('Nombre completo', _s(paciente.nombre)),
            ('Documento', f == null ? 'No registrado' : '${f.tipoDocumento} ${_v(f.numeroDocumento)}'),
            ('Fecha de nacimiento', f?.fechaNacimiento == null ? 'No registrada' : soloFecha(f!.fechaNacimiento!)),
            ('Edad', f?.edad == null ? 'No registrada' : '${f!.edad} años'),
            ('Sexo', _v(f?.sexo ?? '')),
            ('Estado civil', _v(f?.estadoCivil ?? '')),
            ('Ocupación', _v(f?.ocupacion ?? '')),
            ('Teléfono', _v(f?.telefono ?? '')),
            ('Dirección', _v(f?.direccion ?? '')),
            ('Aseguradora (EPS)', _v(f?.eps ?? '')),
            ('Acompañante / responsable', _v(f?.textoAcompanante ?? '')),
            ('Correo', _s(paciente.correo)),
            ('Mano dominante', _v(f?.manoDominante ?? '')),
            ('Mano afectada', _v(f?.manoAfectada ?? '')),
          ]),

          // 2. Valoración inicial
          _titulo('2. Valoración inicial'),
          if (f == null)
            _parrafo('Sin valoración inicial registrada.')
          else ...[
            _pares([
              ('Fecha de valoración', f.fechaValoracion == null ? 'No registrada' : soloFecha(f.fechaValoracion!)),
              ('Diagnóstico', '${_v(f.diagnostico)}${f.codigoCie10.isEmpty ? '' : ' (CIE-10 ${_s(f.codigoCie10)})'}'),
              ('Dolor inicial (EVA)', f.dolorInicial == null ? 'No registrado' : '${f.dolorInicial}/10'),
              ('BCTQ, escala de severidad', f.bctq == null ? 'No registrado' : f.bctq!.toStringAsFixed(1)),
              ('Prueba de Phalen', f.phalen.texto),
              ('Signo de Tinel', f.tinel.texto),
              ('Prueba de Durkan', f.durkan.texto),
            ]),
            pw.SizedBox(height: 6),
            _campo('Motivo de consulta', _v(f.motivoConsulta)),
            _campo('Antecedentes', _v(f.antecedentes)),
            _campo('Objetivos del tratamiento', _v(f.objetivos)),
            pw.SizedBox(height: 4),
            _subtitulo('Goniometría inicial de muñeca'),
            _tabla(
              ['Movimiento', 'Valor inicial', 'Rango normal de referencia'],
              [
                for (final t in TipoEjercicio.values)
                  [
                    t.texto,
                    f.goniometria[t] == null ? 'No registrado' : _g(f.goniometria[t]!),
                    _g(rangoReferencia[t]!),
                  ],
              ],
            ),
          ],

          // 3. Plan de tratamiento
          _titulo('3. Plan de tratamiento (rutina asignada)'),
          ..._plan(),

          // 4. Evolución objetiva
          _titulo('4. Evolución objetiva medida por el dispositivo'),
          ..._evolucion(),

          // 5. Notas de evolución
          _titulo('5. Notas de evolución'),
          if (notas.isEmpty)
            _parrafo('Sin notas registradas.')
          else
            _tabla(
              ['Fecha y hora', 'Nota', 'Registra'],
              [
                for (final n in [...notas]..sort((a, b) => a.fecha.compareTo(b.fecha)))
                  [fechaHora(n.fecha), _s(n.texto), '${_s(n.autor)}${n.tarjeta.isEmpty ? '' : '\nTP ${_s(n.tarjeta)}'}'],
              ],
              anchos: const {0: pw.FixedColumnWidth(80), 1: pw.FlexColumnWidth(), 2: pw.FixedColumnWidth(110)},
            ),

          // Observaciones
          pw.SizedBox(height: 12),
          _parrafo(
            'Observaciones: los ángulos de rango articular fueron medidos con el brazalete SensoTech '
            '(dos sensores inerciales MPU6050, antebrazo y mano) durante la evaluación de cada sesión. '
            'Son datos de apoyo al seguimiento y no reemplazan la goniometría clínica. La intensidad del dolor '
            'fue reportada por el paciente en la escala visual analógica (0 a 10) antes y después de cada sesión. '
            'Este informe se genera para ser anexado a la historia clínica del paciente.',
            tam: 8.5,
          ),

          // Firma
          pw.SizedBox(height: 36),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 220, height: 0.8, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text(_s(fisio.nombre), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Fisioterapeuta', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Tarjeta profesional: ${_v(fisio.tarjetaProfesional ?? '')}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Text('Fecha: ${soloFecha(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------- Secciones ----------------

  List<pw.Widget> _plan() {
    final r = rutina;
    if (r == null) {
      return [
        _parrafo('El paciente realiza la rutina predefinida del programa (sin ajustes del fisioterapeuta):'),
        ..._tablaRutina(Rutina.predefinida()),
      ];
    }
    return [
      _parrafo('Última actualización: ${soloFecha(r.actualizada)}. Descanso entre series: ${r.descanso} s.'),
      ..._tablaRutina(r),
      if (r.nota != null && r.nota!.trim().isNotEmpty) _campo('Indicaciones al paciente', _s(r.nota!)),
    ];
  }

  List<pw.Widget> _tablaRutina(Rutina r) => [
        _tabla(
          ['Ejercicio', 'Dosificación', 'Meta', 'Criterio del dispositivo'],
          [
            for (final e in r.ejercicios)
              [
                _s(e.def.nombre),
                '${e.series} series x ${e.repeticiones} rep.${e.def.sostener > 0 ? '\nSostener ${e.def.sostener} s' : ''}',
                e.meta == null ? 'Progresiva (último máximo + 5°, tope ${_g(e.def.metaMax)})' : 'Fija: ${_g(e.meta!)}',
                _s(e.def.mecanica),
              ],
          ],
          anchos: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(1.3),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(2.6),
          },
        ),
      ];

  List<pw.Widget> _evolucion() {
    if (sesiones.isEmpty) return [_parrafo('El paciente aún no registra sesiones de rehabilitación.')];
    final completas = sesiones.where((s) => s.completa).toList();
    final base = completas.isEmpty ? sesiones.first : completas.first;
    final ultima = completas.isEmpty ? sesiones.last : completas.last;
    final dias = DateTime.now().difference(sesiones.last.fecha).inDays;
    double? promedio(Iterable<int?> v) {
      final l = v.whereType<int>().toList();
      return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
    }

    final antes = promedio(sesiones.map((s) => s.dolorAntes));
    final despues = promedio(sesiones.map((s) => s.dolorDespues));
    String p(double? v) => v == null ? 'Sin dato' : v.toStringAsFixed(1);
    final fd = sesiones.where((s) => s.dolorAntes != null).toList();

    return [
      _pares([
        ('Sesiones registradas', '${sesiones.length}'),
        ('Sesiones completas', '${completas.length} (${(completas.length * 100 / sesiones.length).round()} %)'),
        ('Primera sesión', fechaHora(sesiones.first.fecha)),
        ('Última sesión', '${fechaHora(sesiones.last.fecha)} (${dias == 0 ? 'hoy' : dias == 1 ? 'hace 1 día' : 'hace $dias días'})'),
        ('EVA promedio antes de la sesión', p(antes)),
        ('EVA promedio después de la sesión', p(despues)),
        ('EVA en la primera sesión', fd.isEmpty ? 'Sin dato' : '${fd.first.dolorAntes}/10'),
        ('EVA en la última sesión', fd.isEmpty ? 'Sin dato' : '${fd.last.dolorAntes}/10'),
      ]),
      pw.SizedBox(height: 8),
      _subtitulo('Rango articular: línea base contra última sesión completa'),
      _tabla(
        ['Movimiento', 'Línea base\n${soloFecha(base.fecha)}', 'Última\n${soloFecha(ultima.fecha)}', 'Cambio', '% del rango normal'],
        [
          for (final t in TipoEjercicio.values)
            [
              t.texto,
              _g(base.maximo(t)),
              _g(ultima.maximo(t)),
              '${ultima.maximo(t) - base.maximo(t) >= 0 ? '+' : ''}${(ultima.maximo(t) - base.maximo(t)).round()}°',
              '${(ultima.maximo(t) * 100 / rangoReferencia[t]!).round()} %',
            ],
        ],
        alinearNumeros: true,
      ),
      pw.SizedBox(height: 8),
      _graficaRango(base, ultima),
      pw.SizedBox(height: 10),
      _subtitulo('Registro de sesiones'),
      _tabla(
        ['Fecha y hora', 'Estado', 'Flex.', 'Ext.', 'D. rad.', 'D. cub.', 'EVA antes', 'EVA después'],
        [
          for (final s in sesiones)
            [
              fechaHora(s.fecha),
              s.completa ? 'Completa' : 'Incompleta',
              _g(s.flexion),
              _g(s.extension),
              _g(s.radial),
              _g(s.cubital),
              s.dolorAntes?.toString() ?? '-',
              s.dolorDespues?.toString() ?? '-',
            ],
        ],
        tam: 8.5,
        alinearNumeros: true,
      ),
    ];
  }

  // Barras horizontales en escala de grises: línea base, última y rango normal
  pw.Widget _graficaRango(SesionRehab base, SesionRehab ultima) {
    const ancho = 260.0;
    pw.Widget barra(double v, double ref, PdfColor color) => pw.Stack(
          children: [
            pw.Container(width: ancho, height: 7, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4))),
            pw.Container(width: ancho * (v / ref).clamp(0.0, 1.0), height: 7, color: color),
          ],
        );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final t in TipoEjercicio.values)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 110, child: pw.Text(t.texto, style: const pw.TextStyle(fontSize: 9))),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    barra(base.maximo(t), rangoReferencia[t]!, PdfColors.grey400),
                    pw.SizedBox(height: 1.5),
                    barra(ultima.maximo(t), rangoReferencia[t]!, PdfColors.grey800),
                  ],
                ),
                pw.SizedBox(width: 6),
                pw.Text('${_g(base.maximo(t))} -> ${_g(ultima.maximo(t))} de ${_g(rangoReferencia[t]!)}',
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        pw.Row(
          children: [
            pw.Container(width: 10, height: 6, color: PdfColors.grey400),
            pw.Text('  Línea base     ', style: const pw.TextStyle(fontSize: 8)),
            pw.Container(width: 10, height: 6, color: PdfColors.grey800),
            pw.Text('  Última sesión     (barra completa = rango normal de referencia)',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }

  // ---------------- Piezas ----------------

  pw.Widget _encabezado(pw.Context ctx) {
    if (ctx.pageNumber == 1) return pw.SizedBox();
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Informe de seguimiento fisioterapéutico', style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            '${_s(paciente.nombre)}${ficha == null ? '' : ' - ${ficha!.tipoDocumento} ${_s(ficha!.numeroDocumento)}'}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  pw.Widget _titulo(String t) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border(bottom: pw.BorderSide(width: 0.8)),
        ),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _subtitulo(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _parrafo(String t, {double tam = 10}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(_s(t), style: pw.TextStyle(fontSize: tam), textAlign: pw.TextAlign.justify),
      );

  pw.Widget _campo(String etiqueta, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: '$etiqueta: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: valor, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );

  // Tabla de dos pares por fila: etiqueta | valor | etiqueta | valor
  pw.Widget _pares(List<(String, String)> datos) {
    final filas = <pw.TableRow>[];
    for (var i = 0; i < datos.length; i += 2) {
      pw.Widget celda(String t, {bool negrita = false}) => pw.Padding(
            padding: const pw.EdgeInsets.all(3.5),
            child: pw.Text(t,
                style: pw.TextStyle(fontSize: 9, fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal)),
          );
      final b = i + 1 < datos.length ? datos[i + 1] : ('', '');
      filas.add(pw.TableRow(children: [
        celda(datos[i].$1, negrita: true),
        celda(datos[i].$2),
        celda(b.$1, negrita: true),
        celda(b.$2),
      ]));
    }
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.25),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1.25),
        3: pw.FlexColumnWidth(1.6),
      },
      children: filas,
    );
  }

  pw.Widget _tabla(List<String> encabezados, List<List<String>> filas,
      {Map<int, pw.TableColumnWidth>? anchos, double tam = 9, bool alinearNumeros = false}) {
    return pw.TableHelper.fromTextArray(
      headers: encabezados,
      data: filas,
      border: pw.TableBorder.all(width: 0.5),
      headerStyle: pw.TextStyle(fontSize: tam, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: pw.TextStyle(fontSize: tam),
      cellPadding: const pw.EdgeInsets.all(3.5),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: alinearNumeros ? {for (var i = 1; i < encabezados.length; i++) i: pw.Alignment.center} : null,
      columnWidths: anchos,
      defaultColumnWidth: const pw.FlexColumnWidth(),
    );
  }
}
