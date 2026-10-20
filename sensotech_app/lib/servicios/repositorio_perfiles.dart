import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/perfil.dart';

// Guarda y lee los perfiles en el celular (sin internet)
class RepositorioPerfiles {
  static const _clave = 'perfiles';

  Future<List<Perfil>> leerTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_clave) ?? [];
    return lista
        .map((texto) => Perfil.desdeMapa(jsonDecode(texto) as Map<String, dynamic>))
        .toList();
  }

  Future<void> guardar(Perfil perfil) async {
    final perfiles = await leerTodos();
    perfiles.removeWhere((p) => p.id == perfil.id); // reemplaza si ya existe
    perfiles.add(perfil);
    await _escribir(perfiles);
  }

  Future<void> borrar(String id) async {
    final perfiles = await leerTodos();
    perfiles.removeWhere((p) => p.id == id);
    await _escribir(perfiles);
  }

  Future<void> _escribir(List<Perfil> perfiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _clave,
      perfiles.map((p) => jsonEncode(p.aMapa())).toList(),
    );
  }
}
