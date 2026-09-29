import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Muestra un SVG del proyecto, tolerando que el archivo no exista todavía:
/// si falla, cae a un icono en vez de romper la pantalla.
class AssetImageSafe extends StatelessWidget {
  const AssetImageSafe(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(fallbackIcon, color: Colors.white24, size: 40),
      );
    }
    return SvgPicture.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      // Placeholder estático a propósito: un spinner aquí nunca termina de
      // girar mientras el SVG carga, y en los tests eso hace que
      // pumpAndSettle no se settle nunca.
      placeholderBuilder: (_) => SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Aviso para la demo web, que no incluye las bases de datos.
class AvisoDemo extends StatelessWidget {
  const AvisoDemo(this.texto, {super.key, this.centrado = false});

  final String texto;

  /// true: llena la pantalla (pantallas cuyo contenido completo es la
  /// búsqueda); false: va encajado entre otros elementos.
  final bool centrado;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.info_outline, color: LoboColors.gold, size: 34),
        const SizedBox(height: 12),
        Text(
          'No disponible en la demo web',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
      ],
    );
    if (centrado) return Center(child: Padding(padding: const EdgeInsets.all(28), child: contenido));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LoboColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: LoboColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de la nube que usan las pantallas de pergamino.
class CloudButton extends StatelessWidget {
  const CloudButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.textColor = LoboColors.ink,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 130,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 130,
                height: 84,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(42),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre una URL de forma segura: adds https:// si falta, decide entre
///mailto/tel/http, y avisa al usuario si no se pudo abrir.
Future<void> abrirUrl(BuildContext context, String url) async {
  if (url.trim().isEmpty) return;

  final raw = url.trim();
  String conScheme = raw;
  if (raw.contains('@')) {
    conScheme = 'mailto:$raw';
  } else if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
    conScheme = 'https://$raw';
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final uri = Uri.parse(conScheme);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir: $raw')),
      );
    }
  } catch (_) {
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir: $raw')),
      );
    }
  }
}

/// Un ítem de lista que abre un enlace.
class LinkTile extends StatelessWidget {
  const LinkTile({super.key, required this.titulo, required this.url});

  final String titulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: Colors.white54)),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(color: Colors.white54, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () => abrirUrl(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: Colors.white70)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                  Text(
                    url,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
