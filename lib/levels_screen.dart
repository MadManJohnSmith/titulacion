import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  _LevelsScreenState createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  final ScrollController _scrollController = ScrollController();
  
  // Controladores para los popups
  bool _showFilesPopup = false;
  bool _showLinksPopup = false;
  bool _showContactsPopup = false;

  // Función simplificada para abrir URLs usando launchUrl
  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;

    try {
      // Añadir el prefijo correcto basado en el tipo de URL
      String urlWithScheme = urlString;
      if (urlString.contains('@')) {
        urlWithScheme = 'mailto:$urlString';
      } else if (urlString.replaceAll(RegExp(r'[^0-9]'), '').length >= 10 && !urlString.contains('http')) {
        urlWithScheme = 'tel:${urlString.replaceAll(RegExp(r'[^0-9]'), '')}';
      } else if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
        urlWithScheme = 'https://$urlString';
      }
      
      final Uri url = Uri.parse(urlWithScheme);
      await launchUrl(url);
    } catch (e) {
      debugPrint('Error al abrir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir: $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con color sólido en lugar de SVG scrolleable
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF496D83).withOpacity(0.7),
                  const Color(0xFF002D4C),
                ],
              ),
            ),
          ),
          
          // Contenido principal
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'Niveles por superar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              // Barra de navegación inferior
              Container(
                height: 60,
                color: const Color(0xFF002D4C),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem('Mis archivos', Icons.folder, () {
                      setState(() {
                        _showFilesPopup = true;
                        _showLinksPopup = false;
                        _showContactsPopup = false;
                      });
                    }),
                    _buildVerticalDivider(),
                    _buildNavItem('Links', Icons.link, () {
                      setState(() {
                        _showFilesPopup = false;
                        _showLinksPopup = true;
                        _showContactsPopup = false;
                      });
                    }),
                    _buildVerticalDivider(),
                    _buildNavItem('Contactos', Icons.contact_phone, () {
                      setState(() {
                        _showFilesPopup = false;
                        _showLinksPopup = false;
                        _showContactsPopup = true;
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
          
          // Popups
          if (_showFilesPopup) _buildFilesPopup(),
          if (_showLinksPopup) _buildLinksPopup(),
          if (_showContactsPopup) _buildContactsPopup(),
        ],
      ),
    );
  }

  Widget _buildNavItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          Text(
            title,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white,
    );
  }

  Widget _buildFilesPopup() {
    return _buildPopup(
      title: 'Mis archivos',
      description: 'Hola viajero, aqui encontraras todos los documentos necesarios para que tu aventura se logre con exito.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLinkItem('Formato original de Validación del Certificado de Estudios de preparatoria o bachillerato:', 
              'https://titulacion.buap.mx/sites/default/files/2022/Formato%20de%20validaci%C3%B3n%20de%20certificado%20de%20estudios%20simplificado_TIT.pdf'),
          const SizedBox(height: 10),
          _buildLinkItem('Catálogo de fotografías:', 
              'https://escolar.buap.mx/sites/default/files/Catalogo%20de%20fotografias1.pdf'),
          const SizedBox(height: 10),
          _buildLinkItem('Carta de separación', ''),
        ],
      ),
    );
  }

  Widget _buildLinksPopup() {
    return _buildPopup(
      title: 'Links',
      description: 'Hola viajero, aqui encontraras todos los links necesarios para que tu aventura se logre con exito.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLinkItem('Acta de nacimiento', 'https://www.gob.mx/ActaNacimiento/'),
          _buildLinkItem('Para obtener tu cédula profesional en línea', 'www.gob.mx/cedulaprofesional'),
          _buildLinkItem('Agendar cita en DAE y generar fichas de pagos', 'autoservicios.buap.mx'),
          _buildLinkItem('CURP certificada', 'https://www.gob.mx/curp/'),
          _buildLinkItem('Formato de Validación del Certificado de Estudios', 'https://titulacion.buap.mx/'),
          _buildLinkItem('Certificado de Estudios original de Licenciatura', 'https://escolar.buap.mx/?q=content/certificado-de-estudios-por-autoservicios'),
          _buildLinkItem('Comprobante de la encuesta a egresados', 'http://webserver.siiaa.siu.buap.mx/egresados/registro.solicitud?x=1'),
          _buildLinkItem('Entérate de noticias', 'https://www.facebook.com/TitulacionBUAP'),
          _buildLinkItem('Certificado de liberación de bibliotecas', 'https://bibliotecas.buap.mx/'),
          _buildLinkItem('Certificado de liberación del Servicio Social', 'http://www.serviciosocial.buap.mx/'),
        ],
      ),
    );
  }

  Widget _buildContactsPopup() {
    return _buildPopup(
      title: 'Contactos',
      description: 'Hola viajero, aqui encontraras todos los contactos necesarios para que tu aventura se logre con exito.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Contacto Directo:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            'Coordinación General de Atención a los Universitarios de la BUAP',
            style: TextStyle(color: Colors.white),
          ),
          InkWell(
            onTap: () => _launchUrl('+52 222 229 5500'),
            child: Text(
              'Teléfono: +52 (222) 229 5500',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          InkWell(
            onTap: () => _launchUrl('jorge.avelinos@correo.buap.mx'),
            child: Text(
              'Correo: jorge.avelinos@correo.buap.mx',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            '2. Redes sociales:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            '• Facebook: CGAU BUAP Coordinación General de Atención a los Universitarios',
            style: TextStyle(color: Colors.white),
          ),
          Text(
            '• Instagram: @cgaubuap',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 15),
          Text(
            'Coordinación de titulación de la Facultad de Arquitectura:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            'Encargada: Maricarmen Lara',
            style: TextStyle(color: Colors.white),
          ),
          InkWell(
            onTap: () => _launchUrl('titulacion.fabuap@correo.buap.mx'),
            child: Text(
              'Correo: titulacion.fabuap@correo.buap.mx',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            '3. Contacto externo:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            'Víctor - Departamento de Titulación de la Facultad de Arquitectura',
            style: TextStyle(color: Colors.white),
          ),
          InkWell(
            onTap: () => _launchUrl('+52 221 256 998'),
            child: Text(
              'Teléfono: 221 256 998',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopup({
    required String title, 
    required String description, 
    required Widget content
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFilesPopup = false;
          _showLinksPopup = false;
          _showContactsPopup = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Evita que el pop-up se cierre al hacer clic dentro de él
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF002D4C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: SingleChildScrollView(
                      child: content,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showFilesPopup = false;
                        _showLinksPopup = false;
                        _showContactsPopup = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF002D4C),
                    ),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkItem(String title, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        if (url.isNotEmpty)
          InkWell(
            onTap: () => _launchUrl(url),
            child: Text(
              url,
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}