import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            '1. Contacto Directo: Coordinación General de Atención a los Universitarios de la BUAP al teléfono: +52 (222) 229 5500 o al correo: jorge.avelinos@correo.buap.mx.',
            style: TextStyle(color: Colors.white),
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
          Text(
            'Visitar la coordinación de titulación de la Facultad de Arquitectura, quien está encargada: Maricarmen Lara o mandando un correo a: titulacion.fabuap@correo.buap.mx.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 15),
          Text(
            '3. Contacto externo: Para cualquier consulta, envía un mensaje o realiza una llamada a Víctor, miembro del Departamento de Titulación de la Facultad de Arquitectura, al número 221 256 998.',
            style: TextStyle(color: Colors.white),
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
                Container(
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
                  child: Text('Cerrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF002D4C),
                  ),
                ),
              ],
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
          Text(
            url,
            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
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