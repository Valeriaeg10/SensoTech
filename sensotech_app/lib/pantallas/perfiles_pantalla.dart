import 'package:flutter/material.dart';
import '../modelos/perfil.dart';
import '../servicios/brazalete.dart';
import '../servicios/repositorio_perfiles.dart';
import '../tema/colores.dart';
import '../tema/tema_app.dart';
import '../widgets/icono_chip.dart';
import '../widgets/logo.dart';
import 'crear_perfil_pantalla.dart';
import 'panel_pantalla.dart';

// Primera pantalla: elegir o crear usuario (hoja 1)
class PerfilesPantalla extends StatefulWidget {
  final Brazalete brazalete;

  const PerfilesPantalla({super.key, required this.brazalete});

  @override
  State<PerfilesPantalla> createState() => _PerfilesPantallaState();
}

class _PerfilesPantallaState extends State<PerfilesPantalla> {
  final _repo = RepositorioPerfiles();
  List<Perfil> _perfiles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final perfiles = await _repo.leerTodos();
    if (!mounted) return;
    setState(() {
      _perfiles = perfiles;
      _cargando = false;
    });
  }

  Future<void> _crear() async {
    final nuevo = await Navigator.push<Perfil>(
      context,
      MaterialPageRoute(builder: (_) => const CrearPerfilPantalla()),
    );
    if (nuevo == null) return; // canceló
    await _repo.guardar(nuevo);
    await _cargar();
  }

  Future<void> _borrar(Perfil p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar perfil'),
        content: Text('¿Borrar a ${p.nombre}? Se pierde su historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.borrar(p.id);
    await _cargar();
  }

  void _abrir(Perfil p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PanelPantalla(perfil: p, brazalete: widget.brazalete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LogoSensoTech(),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text('Perfiles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  if (_perfiles.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colores.azulSuave,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_perfiles.length}',
                          style: const TextStyle(color: Colores.primario, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(child: _contenido()),
            ],
          ),
        ),
      ),
      floatingActionButton: _perfiles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _crear,
              backgroundColor: Colores.primario,
              foregroundColor: Colores.blanco,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo perfil'),
            ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Sin perfiles: invitar a crear el primero
    if (_perfiles.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IconoChip(icono: Icons.group_add_rounded, tamano: 80),
          const SizedBox(height: 16),
          const Text('Todavía no hay perfiles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Crea uno para guardar el progreso',
              style: TextStyle(color: Colores.textoSuave)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _crear,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Crear perfil'),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _perfiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = _perfiles[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _abrir(p),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: decoracionTarjeta(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colores.azulSuave,
                  child: Text(p.nombre[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colores.primario, fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          const Icon(Icons.work_outline_rounded, size: 14, color: Colores.textoSuave),
                          const SizedBox(width: 4),
                          Text('Trabajo ${p.tipoTexto.toLowerCase()}',
                              style: const TextStyle(color: Colores.textoSuave)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colores.textoSuave),
                  onPressed: () => _borrar(p),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colores.textoSuave),
              ],
            ),
          ),
        );
      },
    );
  }
}
