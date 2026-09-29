/// true cuando la build es la **demo web** de GitHub Pages.
///
/// La demo se compila con `--dart-define=DEMO_WEB=true` y un script que saca
/// las bases de datos del bundle (`tools/preparar_demo_web.sh`), para que el
/// padrón de alumnos no quede descargable desde el sitio público. Con la
/// bandera, los buscadores se desactivan y la UI lo explica en vez de fallar.
const bool kDemoWeb = bool.fromEnvironment('DEMO_WEB');
