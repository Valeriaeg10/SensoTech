import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modelos/cuenta.dart';
import '../modelos/ficha_clinica.dart';
import '../servicios/nube.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/campo_texto.dart';
import '../widgets/formulario_ficha.dart';
import '../widgets/icono_chip.dart';

// El fisio agrega un paciente: crea su cuenta con contraseña temporal y abre su historia clínica
class AgregarPacientePantalla extends StatefulWidget {
  final Cuenta fisio;

  const AgregarPacientePantalla({super.key, required this.fisio});

  @override
  State<AgregarPacientePantalla> createState() => _AgregarPacientePantallaState();
}

class _AgregarPacientePantallaState extends State<AgregarPacientePantalla> {
  final _form = GlobalKey<FormState>();
  final _ficha = GlobalKey<FormularioFichaState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  bool _consentimiento = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() => _error = null);
    final valido = _form.currentState!.validate();
    final falta = _ficha.currentState!.faltantes();
    if (!valido || falta != null) {
      setState(() => _error = falta ?? 'Revisa los campos marcados');
      return;
    }
    if (!_consentimiento) {
      setState(() => _error = 'Confirma el consentimiento informado del paciente');
      return;
    }
    setState(() => _guardando = true);
    final clave = claveTemporal();
    try {
      final paciente = await nube.crearPaciente(
        fisio: widget.fisio,
        nombre: _nombre.text,
        correo: _correo.text,
        claveTemporal: clave,
        ficha: _ficha.currentState!.construir(''),
      );
      await nube.agregarNota(NotaEvolucion(
        pacienteId: paciente.id,
        fecha: DateTime.now(),
        texto: 'Ingreso del paciente al programa de rehabilitación con SensoTech. Valoración inicial registrada.',
        autor: widget.fisio.nombre,
        tarjeta: widget.fisio.tarjetaProfesional ?? '',
      ));
      if (!mounted) return;
      await _mostrarCredenciales(paciente, clave);
      if (mounted) Navigator.pop(context, true);
    } on ErrorCuenta catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _mostrarCredenciales(Cuenta p, String clave) {
    final texto = 'SensoTech\nUsuario: ${p.correo}\nContraseña temporal: $clave';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const IconoChip(icono: Icons.how_to_reg_rounded, tamano: 52),
        title: const Text('Paciente creado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entrega estos datos al paciente para que ingrese a la app:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colores.azulSuave, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Usuario', style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
                  SelectableText(p.correo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Contraseña temporal', style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
                  SelectableText(clave,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 3)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('Al primer ingreso la app le pedirá crear su propia contraseña.',
                style: TextStyle(color: Colores.textoSuave, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: texto));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos copiados')));
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar paciente')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: decoracionTarjeta(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        IconoChip(icono: Icons.person_add_alt_1_rounded, tamano: 34),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cuenta del paciente', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text('Se genera una contraseña temporal', style: TextStyle(color: Colores.textoSuave, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CampoTexto(
                      controlador: _nombre,
                      etiqueta: 'Nombres y apellidos *',
                      icono: Icons.badge_outlined,
                      mayusculas: TextCapitalization.words,
                      validar: (v) => v.trim().split(RegExp(r'\s+')).length < 2 ? 'Escribe nombre y apellido' : null,
                    ),
                    const SizedBox(height: 12),
                    CampoTexto(
                      controlador: _correo,
                      etiqueta: 'Correo (será su usuario) *',
                      icono: Icons.mail_outline_rounded,
                      teclado: TextInputType.emailAddress,
                      validar: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                          ? null
                          : 'Escribe un correo válido',
                    ),
                  ],
                ),
              ),
              FormularioFicha(key: _ficha, ficha: const FichaClinica(pacienteId: '')),
              InkWell(
                onTap: () => setState(() => _consentimiento = !_consentimiento),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentimiento,
                      onChanged: (v) => setState(() => _consentimiento = v ?? false),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'El paciente firmó el consentimiento informado y autorizó el tratamiento de sus '
                          'datos personales y de salud (Ley 1581 de 2012).',
                          style: TextStyle(fontSize: 12, color: Colores.textoSuave),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colores.rojo)),
                ),
              FilledButton.icon(
                onPressed: _guardando ? null : _crear,
                icon: const Icon(Icons.person_add_rounded),
                label: Text(_guardando ? 'Creando…' : 'Crear paciente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
