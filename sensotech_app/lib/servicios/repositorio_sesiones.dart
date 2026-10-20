import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/sesion.dart';

// Guarda las jornadas de cada perfil en el celular
class RepositorioSesiones {
  String _clave(String perfilId) => 'sesiones_$perfilId';

  // Más recientes primero
  Future<List<SesionPrevencion>> leer(String perfilId) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_clave(perfilId)) ?? [];
    final sesiones = lista
        .map((t) => SesionPrevencion.desdeMapa(jsonDecode(t) as Map<String, dynamic>))
        .toList();
    sesiones.sort((a, b) => b.fecha.compareTo(a.fecha));
    return sesiones;
  }

  Future<void> guardar(SesionPrevencion sesion) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_clave(sesion.perfilId)) ?? [];
    lista.add(jsonEncode(sesion.aMapa()));
    await prefs.setStringList(_clave(sesion.perfilId), lista);
  }

  // Al borrar un perfil se borra su historial
  Future<void> borrarDePerfil(String perfilId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave(perfilId));
  }
}
