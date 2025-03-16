import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:titulacion/widgets/curved_text.dart';
import 'dart:math' as math;

class PromedioScreen extends StatelessWidget {
  const PromedioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con color en lugar de SVG de fondo completo
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF496D83).withOpacity(0.8),
          ),
          
          // Contenido central
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Cambiando SVG por imagen PNG
                    Image.asset(
                      'assets/images/parchment_Open.png',
                      width: 300,
                      height: 350,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      top: 35,
                      child: CurvedText(
                        text: 'TITULACION POR PROMEDIO',
                        radius: 100,
                        textStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 60), // Ajustar el espacio para el título
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(25, 0, 5, 0),
                                  child: Text(
                                    'Bienvenido valiente estudiante felicidades por llegar a esta punto sin haber reprobado, sin haber recursado ninguna materia y sin haber pedido permiso por baja temporal. Ahora solo queda terminar tu proceso de titulacion, es momento de empezar el vuelo hacia tu titulo profesional, reune tus documentos y vuela por los cielos de tu proceso final.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Usando try-catch para SVG
                SvgPicture.asset(
                  'assets/images/lobo_aviador.svg',
                  width: 200,
                  height: 200,
                  placeholderBuilder: (BuildContext context) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey,
                    child: const Icon(Icons.person, size: 100),
                  ),
                ),
              ],
            ),
          ),
          // Botón Siguiente
          Positioned(
            bottom: 30,
            right: 30,
            child: GestureDetector(
              onTap: () {
                // Navegar a la siguiente pantalla
                Navigator.pushNamed(context, '/levels');
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Usando try-catch para SVG
                  SvgPicture.asset(
                    'assets/images/cloud.svg',
                    width: 120,
                    height: 80,
                    placeholderBuilder: (BuildContext context) => Container(
                      width: 120,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Text(
                    'Siguiente',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}