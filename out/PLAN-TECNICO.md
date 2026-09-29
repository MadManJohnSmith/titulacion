# Plan técnico: modalidades reales por unidad académica

**Fecha:** 29 de septiembre de 2026. **Alcance:** diseño; no se editan archivos de código ni assets en esta tarea. La base normativa aportada por el encargo es el Reglamento General de Titulación BUAP, H. Consejo Universitario 23-nov-2015, art. 7, que reconoce ocho modalidades. El reglamento acredita el marco; cada oferta y requisito de unidad exige su publicación oficial propia.

## 1. Evidencia y estado actual

- `lib/models/models.dart:7-53` solo modela `Ruta` global con id, texto, assets y niveles; `:141-175` modela `Facultad` sin modalidades.
- `lib/services/content_repository.dart:22-37` carga `routes.json` y `facultades.json` independientemente.
- `lib/state/app_state.dart:20-31,95-103,122-141` persiste una ruta y progreso indexado por `rutaId`.
- `lib/screens/register_screen.dart:11-14,119-121` ya exige que el alumno elija unidad; no hay que “hacerla obligatoria”: hay que asociar catálogo, reiniciar selección incompatible y resolver re-registro.
- `lib/screens/route_selection_screen.dart:11-19` recibe únicamente `Ruta`; por eso la solución incluye cambiar el contrato de esta pantalla **y el punto que la construye/navega** (actualmente `home_screen.dart`, que debe localizarse y modificarse en el mismo branch de integración).
- `assets/json/routes.json:1-11` contiene rutas globales; `assets/json/facultades.json:1-12` contiene unidades/contacto sin relación.
- `pubspec.yaml:68-77` ya empaqueta `assets/json/`.
- `test/data_test.dart:21-26` lee assets reales.
- `out/modalidades-por-facultad.json` y `out/PLAN-ASSETS.md` no existen en el workspace observado; no se inventa su contenido.
- Check solicitado ejecutado exactamente: `cd /home/alan/Documents/LoboApp/titulacion && flutter test`; salida: código 127, `zsh: command not found: /home/alan/Applications/ZCode/ZCode.AppImage`. Suite no ejecutada; no es evidencia de aprobación.

## 2. Fuente normativa única y arquitectura

Hay **un solo catálogo normativo**, `assets/json/catalogo_modalidades.json`. No se crearán `modalidades.json`, `unidades_modalidades.json` ni `Ruta.variantes` como fuentes adicionales. `routes.json` conserva únicamente las rutas base legadas y las nuevas bases acreditadas; el catálogo contiene la relación unidad→modalidad y los deltas. Si el backend entrega el catálogo, su contenido reemplaza en caché al asset, pero no crea otra representación.

Una modalidad es `{modalidadId, unidadClave, rutaId, ...}` y apunta a una ruta base. `Ruta` sigue siendo el contrato de niveles usado por mapa/detalle; `RutaCompuesta` es una vista inmutable calculada por repositorio. La variante no copia la ruta ni muta la base.

### Contrato de flujo y navegación

1. `RegisterScreen` guarda una `unidadClave` válida.
2. `HomeScreen` llama `ContentRepository.modalidadesDeUnidad(unidadClave)` y navega a `ModalityCatalogScreen` (o, durante transición, a `RouteSelectionScreen` con ese catálogo), nunca a una lista global.
3. `RouteSelectionScreen` cambia su constructor a `required List<ModalidadUnidad> modalidades` y `required ContentRepository repository`; muestra solo esa lista. Al seleccionar, resuelve `RutaCompuesta`, llama `state.elegirModalidad(modalidadId, rutaId)` y navega a mapa.
4. `MapScreen` y `LevelDetailScreen` reciben `RutaCompuesta`/la interfaz `Ruta` efectiva y no vuelven a consultar una lista global. El flujo legado mantiene un adaptador: si no hay catálogo seleccionado, `rutaPorId(id)` devuelve la ruta base y conserva navegación existente.
5. Si la unidad está en `unidad_no_publica_catalogo`, se muestran cero modalidades acreditadas, un mensaje explícito “esta unidad no publica catálogo”, el rastro de URLs y CTA a contactos/DAE; no se muestran rutas como si fueran oferta de la unidad. El reglamento puede abrirse como información marco separada, sin permitir seleccionarlo como oferta acreditada.

Este cambio de `home_screen.dart` es integración del **núcleo de navegación**, no una pantalla nueva del frente features; queda en núcleo para que no exista una ventana donde se siga navegando a rutas globales.

## 3. Esquema único (JSONC ilustrativo)

### 3.1 Ruta base y modalidad en el catálogo

```jsonc
// routes.json: solo ruta base; id legado inmutable
{"rutas":[{"id":"ceneval","nombre":"Presentación del examen CENEVAL-EGEL","descripcion":"Contenido común acreditado por la fuente base.","niveles":[{"numero":0,"titulo":"Inicio","descripcion":"...","icono":"","mascota":"","fondo":"","esInicio":true,"pasos":[],"documentos":[]}]}]}

// catalogo_modalidades.json: única relación normativa
{
  "schemaVersion": 1,
  "catalogoVersion": "2026.09.29-001",
  "generadoEn": "2026-09-29T12:00:00Z",
  "unidades": [{
    "clave": "FCC", "nombreOficial": "Facultad de Ciencias de la Computación",
    "estadoCatalogo": "publicado",
    "fuentes": [{"id":"fcc-catalogo-2026","titulo":"Publicación oficial FCC","url":"https://ejemplo.invalid/reemplazar","fechaPublicacion":"2026-09-01","consultadoEn":"2026-09-29T12:00:00Z"}],
    "modalidades": [{
      "modalidadId":"fcc-ceneval", "rutaId":"ceneval", "nombreOficial":"Presentación del examen CENEVAL-EGEL",
      "vigenteDesde":"2026-09-01", "vigenteHasta":null,
      "fuenteIds":["fcc-catalogo-2026"],
      "perfilAplicacion":{"carreraIds":["fcc-carrera-oficial"],"planes":[{"id":"plan-oficial","cohortes":{"desde":2020,"hasta":null}}]},
      "requisitos":{"promedioMinimo":null,"permiteRecursar":null,"porcentajeCreditosMinimo":100,"exigeServicioSocial":null,"exigeEgelCeneval":true,"exigeTrabajoEscrito":null,"exigeExperienciaProfesional":false},
      "operaciones":[{"orden":1,"op":"agregar","targetTipo":"nivel","targetId":"1","paso":{"id":"fcc-validar-egel","titulo":"Validar convocatoria con FCC","detalle":"Texto que debe provenir de la fuente."}}]
    }]
  }]
}
```

Los dominios y fechas anteriores son **marcadores no publicables** (`ejemplo.invalid`); el validador los rechaza. Un fixture de diseño no es dato BUAP. Producción solo acepta URL HTTPS real, fecha ISO-8601 UTC para `consultadoEn`, fecha ISO `YYYY-MM-DD` para vigencia/publicación, y fuente oficial resoluble.

`RequisitosElegibilidad` incluye `perfilAplicacion`: `carreraIds`, `planes[].id` y rango de cohorte. El alumno debe modelar/guardar `carreraId`, `planId` y `anioIngreso` (opcionales); sin coincidencia no se calcula y se muestra “confirmar con la unidad”. Cada número puede ser `null` (no publicado), nunca falso por omisión.

### 3.2 Unidad sin catálogo

```jsonc
{"clave":"FCB","nombreOficial":"Facultad de Ciencias Biológicas","estadoCatalogo":"unidad_no_publica_catalogo","fuentesConsulta":[{"url":"https://sitio-oficial-real-consultado","consultadoEn":"2026-09-29T12:00:00Z","resultado":"sin_catalogo_publicado"}],"modalidades":[]}
```

Para ese estado son obligatorios `fuentesConsulta[]`, URL HTTPS consultada, timestamp UTC, resultado y contacto/DAE de respaldo si existe. No se permite `NO VERIFICADO`, URL vacía, `YYYY-MM-DD`, `URL_OFICIAL_EXACTA`, dominio `example` ni modalidad sin `fuenteIds`. La lista exacta de 34 claves se toma de `assets/json/facultades.json` y se valida contra ella; hasta tener fuentes no se afirma qué modalidades ofrece cada una.

### 3.3 Operaciones y composición

`targetTipo` es `nivel`, `paso` o `documento`; `targetId` es obligatorio y los niveles existentes se identifican por `numero` serializado. `agregar` exige id nuevo; `reemplazar` exige id existente y contiene objeto completo; `quitar` exige id existente y no contiene objeto. Las operaciones se ordenan por `orden` único; dos operaciones sobre el mismo id o `orden` duplicado son error. Target inexistente, id duplicado, operación desconocida o referencia de nivel inexistente invalida **solo esa modalidad**, la excluye del listado y deja un error auditable; no invalida rutas/unidades válidas ni permite fallback silencioso. No se escriben cambios parciales.

## 4. Progreso, cambio de unidad y migración

Desde `schemaVersion` de estado 1 (actual implícito) a 2:

- claves existentes: `alumno`, `facultad`, `ruta`, `progreso` se leen sin alterarlas;
- nuevas: `estadoSchema:2`, `modalidadActiva`, `rutaActivaBase`, `contextoAlumno` (`carreraId`, `planId`, `anioIngreso`);
- progreso nuevo se guarda exclusivamente bajo `modalidad:<modalidadId>`; nunca bajo `rutaId`.

Regla de lectura: una modalidad nueva **no lee jamás** `progreso` legado por `rutaId`, aunque comparta `promedio` o `ceneval`. El progreso legado solo se lee mediante el adaptador de la ruta global antigua cuando `modalidadActiva == null`; al elegir una modalidad se inicia progreso vacío. Así se evita mezcla; no se migra automáticamente por “misma ruta”. Una migración explícita futura requeriría correspondencia única acreditada y confirmación del alumno.

`registrar(alumno, facultadClave)` debe exigir unidad no nula. Si cambia matrícula/alumno o unidad, se limpia `modalidadActiva` y `rutaActivaBase`, pero no se borra progreso histórico: queda aislado por namespace. `elegirFacultad` aplica la misma invalidación. Si la unidad no cambia, el re-registro conserva modalidad válida; si deja de estar publicada, la deselecciona y ofrece el CTA de fuente/contacto. Migración idempotente: escribir claves nuevas en una transacción lógica temporal, validar, y solo después marcar `estadoSchema:2`; nunca eliminar claves antiguas hasta confirmar escritura.

## 5. Nuevas rutas

No se crean bases jugables `tesis`, `diplomado`, `experiencia-profesional` o `seminario` con contenido vacío, marcadores o trámites inventados. Se registran como IDs reservados en el catálogo solo cuando exista fuente oficial y contenido de pasos/documentos verificable. Antes de eso la UI puede mostrar “modalidad reconocida por el art. 7; contenido de esta unidad pendiente de publicación oficial” como información no seleccionable. Cada paso/documento tendrá `fuenteIds` heredado o propio.

## 6. Fuente remota autenticada y fallback

El manifiesto remoto mínimo es `{catalogoVersion, generadoEn, expiraEn, urlContenido, sha256, firma}`. `firma` contiene `{algoritmo:"Ed25519", claveId, valorBase64, payloadCanonicoSha256}`; el payload canónico es JSON RFC 8785/JCS, UTF-8, y la firma cubre versión, fechas, URL, hash y contenido hash. La app incluye un almacén de confianza con clave pública Ed25519 y `claveId`; la rotación requiere una nueva versión de app o una cadena de delegación firmada, nunca una clave descargada del mismo endpoint. SHA-256 verifica integridad; la firma autentica al proveedor. Si cambian conjuntamente URL y hash, la firma falla salvo que una clave confiable haya firmado el manifiesto.

Solo HTTPS, sin seguir redirecciones a otro host salvo allowlist explícita; timeout; límites de tamaño; validación de esquema; firma antes de guardar; escritura atómica de archivo temporal + rename. Se conserva último paquete válido y asset embebido. Se prueban firma válida/inválida, sustitución conjunta, host/redirección, timeout, vencimiento, hash, persistencia atómica, recuperación y rollback.

## 7. Archivos y frentes disjuntos

### Frente **núcleo**

- `lib/models/models.dart`: modelos de fuente, requisitos con perfil carrera/plan/cohorte, catálogo, modalidad y ruta compuesta.
- `assets/json/routes.json`: conservar ids y bases; añadir solo contenido acreditado.
- `assets/json/catalogo_modalidades.json`: único catálogo normativo.
- `lib/services/content_repository.dart`: cargar/validar/componer catálogo y actualización firmada.
- `lib/state/app_state.dart`: schema 2, contexto académico, namespaces aislados y cambio de unidad.
- `lib/screens/register_screen.dart`: conservar validación existente, guardar contexto/unidad y aplicar invalidación al cambiar.
- `lib/screens/route_selection_screen.dart`: recibir modalidades filtradas, fuentes y estado vacío.
- `lib/screens/home_screen.dart`: cambiar el punto de construcción/navegación para pasar catálogo filtrado; adaptador legado explícito.
- `test/catalog_data_test.dart`, `test/app_state_migration_test.dart`, `test/content_composition_test.dart`, `test/content_update_security_test.dart`, `test/navigation_contract_test.dart`, y extensión de `test/data_test.dart`.

### Frente **features**

- `lib/screens/modality_catalog_screen.dart`, `eligibility_screen.dart`, `source_detail_screen.dart`.
- `lib/widgets/modality_card.dart`, `eligibility_result.dart`.
- `test/modality_catalog_screen_test.dart`, `eligibility_screen_test.dart`, `source_detail_screen_test.dart`.

`map_screen.dart` y `level_detail_screen.dart` pertenecen al frente núcleo de integración porque consumen `Ruta`/navegación existente; no se colocan en features. Ningún archivo aparece en ambos frentes. El orden es núcleo (contratos, flujo y estado) → features (presentación).

## 8. Pruebas obligatorias

1. Repetir exactamente `cd /home/alan/Documents/LoboApp/titulacion && flutter test` cuando exista Flutter; el intento de esta tarea terminó en código 127 indicado arriba. Ejecutar también `flutter analyze` (no ejecutado aquí).
2. 34 claves únicas comparadas automáticamente con `facultades.json`; cada unidad tiene estado, y estado sin catálogo tiene rastro URL/fecha/resultado.
3. IDs legados y `rutaPorId` intactos; flujo legado completo de selección→mapa→nivel; ruta compuesta no muta base.
4. Filtrado: FCC solo muestra modalidades FCC; unidad sin catálogo muestra cero rutas acreditadas y CTA, nunca pantalla vacía sin salida.
5. Operaciones: agregar/reemplazar/quitar, targets inválidos, conflictos y aislamiento de modalidad inválida.
6. Elegibilidad por carrera/plan/cohorte: coincidencia, fuera de rango y dato nulo; desconocido nunca equivale a aprobado.
7. Migración v1→v2, estado parcial, repetición, ruta sin correspondencia, selección nueva que comparte `rutaId`, cambio FCC→otra unidad y alumno nuevo; verificar explícitamente que completar `fcc-ceneval` no aparece en otra modalidad.
8. Seguridad remota: firma válida/inválida, sustitución de URL+hash, clave desconocida/rotación, HTTPS y redirecciones, timeout, vencimiento, hash, escritura atómica y último paquete válido.
9. Widget tests de registro, navegación filtrada, estado sin catálogo, fuente/vigencia y enlaces.

## 9. Riesgos y límites

- Las fuentes concretas de las 34 unidades no están en los archivos observados; no se inventan modalidades, fechas ni URLs.
- El art. 7 no basta para acreditar trámites de unidad.
- Cambios de plan/cohorte pueden alterar elegibilidad; sin contexto suficiente se debe pedir confirmación.
- La suite no pudo ejecutarse por ausencia efectiva de Flutter en este entorno; ningún check se marca aprobado.
- La seguridad depende de proteger la clave pública confiable y el proceso de rotación; SHA-256 sin firma no se acepta.
