import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'contacts_screen.dart';
import 'directory_screen.dart';
import 'profile_screen.dart';

/// El menú hamburguesa: el punto de entrada a todo lo que no es jugar.
///
/// No venía en el zip de diseño (la carpeta estaba vacía), así que se hizo con
/// los colores y las formas de las demás pantallas.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoboApp'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Cerrar',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _perfil(context),
          const SizedBox(height: 20),
          const Text(
            'Tu camino',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _item(
            context,
            icon: Icons.map_outlined,
            titulo: 'Mis rutas',
            subtitulo: 'Ver en qué vas y continuar donde te quedaste',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ayuda',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _item(
            context,
            icon: Icons.support_agent,
            titulo: 'Contactos y links',
            subtitulo: 'A quién preguntarle y dónde hacer cada trámite',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactsScreen(state: state),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icon: Icons.badge_outlined,
            titulo: 'Directorio BUAP',
            subtitulo: 'Buscar a un trabajador por nombre o matrícula',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DirectoryScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _item(
            context,
            icon: Icons.person_outline,
            titulo: 'Mi perfil',
            subtitulo: 'Tus datos, tu facultad y tu avance',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(state: state)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sobre LoboApp',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _perfil(BuildContext context) {
    final alumno = state.alumno;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: LoboColors.gold,
            child: Icon(Icons.person, color: LoboColors.deepBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (alumno != null && alumno.nombre.isNotEmpty)
                      ? alumno.nombre
                      : 'Invitado',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  (alumno != null && alumno.matricula.isNotEmpty)
                      ? 'Matrícula ${alumno.matricula}'
                      : 'Entraste como invitado',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: LoboColors.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
