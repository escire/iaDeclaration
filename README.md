# aiDeclaration — Plugin para OJS 3.5

Plugin genérico para Open Journal Systems **3.5** que integra un formulario de **declaración de transparencia en el uso de inteligencia artificial** en el flujo de envío de artículos. Utiliza la API de [declarador.usoeticoia.org](https://declarador.usoeticoia.org) para crear, registrar y verificar declaraciones.

---

## Tabla de contenidos

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Flujo de uso](#flujo-de-uso)
  - [Autor — Paso 6 del wizard de envío](#autor--paso-6-del-wizard-de-envío)
  - [Editor — Panel de publicación en el dashboard](#editor--panel-de-publicación-en-el-dashboard)
  - [Vista pública del artículo](#vista-pública-del-artículo)
- [Arquitectura técnica](#arquitectura-técnica)

---

## Características

- **Paso dedicado en el wizard de envío (OJS 3.5)**: el plugin inyecta un paso "Declaración de IA" entre la revisión y la confirmación del envío. El autor declara si usó IA generativa con tres opciones:
  - *Sí usé IA* — completa un formulario detallado (herramienta, prompts, tipos de uso, nivel de revisión humana, licencia) y crea la declaración en la API
  - *No usé IA* — registra una declaración de no-uso
  - *Ya tengo una declaración* — busca y vincula una declaración existente por ID o hash

- **Declaración obligatoria u opcional**: configurable por revista. Si es obligatoria, el autor no puede avanzar al paso de confirmación sin completar el proceso.

- **Fallback ante fallos de la API**: si la API falla 3 veces consecutivas, el autor puede continuar el envío. El sistema marca la publicación como "declaración pendiente" para que el editor la registre posteriormente.

- **Panel editorial (dashboard OJS 3.5)**: elemento "Declaración IA" bajo el menú "Publicación" del panel lateral del flujo editorial que permite a editores y gestores:
  - Ver el estado (IA usada / Sin IA), el hash de validación y la URL de la declaración
  - Actualizar la URL de la declaración
  - Registrar declaraciones en artículos publicados antes de la instalación del plugin
  - Ver el aviso de bypass cuando el autor no pudo completar el proceso

- **Insignia en la vista pública del artículo**: muestra la insignia correspondiente (IA usada / Sin IA) con enlace a la declaración completa y el hash de verificación para ambos casos.

- **Localización**: soporte completo para español (`es_ES`) e inglés (`en_US`).

---

## Requisitos

| Componente | Versión |
|------------|---------|
| Open Journal Systems | 3.5.x |
| PHP | 8.0 o superior |
| Cuenta en declarador.usoeticoia.org | API Key válida |

---

## Instalación

1. Copiar la carpeta `aiDeclaration` en `plugins/generic/` de tu instalación OJS:

   ```
   plugins/generic/aiDeclaration/
   ```

2. Acceder al panel de administración de OJS:
   **Configuración del sitio → Plugins → Plugins instalados → Plugins genéricos**

3. Activar **"Declaración de Transparencia en el Uso de IA"**.

4. Hacer clic en **"Ajustes"** para configurar el plugin.

---

## Configuración

Desde **Configuración del sitio → Plugins → aiDeclaration → Ajustes**:

| Campo | Descripción |
|-------|-------------|
| **URL del servidor Declarador** | Dominio de la instancia Declarador. Dejar vacío para usar `https://declarador.usoeticoia.org`. Para servidor propio: `https://mi-declarador.ejemplo.org` |
| **API Key** | Clave proporcionada por el administrador de declarador.usoeticoia.org |
| **Requerir declaración en todos los envíos** | Si está activo, el autor no puede avanzar a la confirmación sin vincular una declaración |

Después de configurar, usar el botón **"Probar conexión"** para verificar que OJS puede alcanzar el servidor Declarador.

---

## Flujo de uso

### Autor — Paso 6 del wizard de envío

En OJS 3.5 el wizard de envío es una SPA Vue 3. El plugin inyecta un paso "Declaración de IA" (paso 6) entre la revisión del envío (paso 5) y la confirmación (paso 7).

El formulario de declaración aparece al llegar al paso 6.

**Opción A — Sí usé IA generativa:**
1. Seleccionar los tipos de uso (redacción, análisis, traducción, etc.)
2. Indicar la herramienta utilizada (nombre, versión, proveedor, mes y año)
3. Describir el propósito específico
4. Agregar los prompts utilizados
5. Opcionalmente indicar el modo de integración del contenido y el nivel de revisión humana
6. Hacer clic en **"Crear declaración"** — se realiza una llamada AJAX a la API y se muestra el badge de confirmación con el ID asignado
7. Hacer clic en **"Continuar"**

**Opción B — No usé IA generativa:**
1. Hacer clic en **"Registrar declaración sin IA"**
2. Se crea la declaración de no-uso en la API y aparece el badge de confirmación
3. Hacer clic en **"Continuar"**

**Opción C — Ya tengo una declaración:**
1. Introducir el ID (8 caracteres) o hash de verificación (16 caracteres) de la declaración ya existente
2. Hacer clic en **"Buscar declaración"** — se verifica contra la API
3. Si es válida, aparece el badge de confirmación
4. Hacer clic en **"Continuar"**

> **Nota:** el badge de confirmación debe estar visible antes de poder avanzar. Si la declaración es obligatoria y el autor intenta saltar este paso, el sistema lo bloquea.

---

### Editor — Panel de publicación en el dashboard

En OJS 3.5, el flujo editorial es una SPA Vue 3 en el dashboard. El plugin añade un elemento **"Declaración IA"** bajo el menú **"Publicación"** del panel lateral usando las APIs oficiales `pkp.registry.registerComponent` y `pkp.registry.storeExtend`.

**Artículo con declaración:**
- Se muestra el badge de estado (verde: IA usada / gris: sin IA)
- Hash de validación (solo lectura)
- Campo para actualizar la URL de la declaración
- El botón "Guardar URL" actualiza la URL; si el artículo está publicado y tiene una declaración real vinculada, el backend rechaza la edición

**Artículo sin declaración** (publicado antes de la instalación o bypass activado):
- Formulario para registrar la declaración:
  - Seleccionar si se usó IA (Sí / No)
  - Introducir la URL de la declaración
  - Opcionalmente introducir el ID (el sistema obtiene el hash desde la API automáticamente)
- Al guardar, el panel recarga mostrando la declaración registrada

**Aviso de bypass:**
- Si el autor activó el bypass durante el envío (por fallos de la API), aparece un aviso naranja indicando que la declaración está pendiente de registro

---

### Vista pública del artículo

En la página de detalle del artículo publicado se muestra la sección **"Declaración de IA"** en la barra lateral:

- **IA usada**: insignia verde con enlace a la declaración completa en declarador.usoeticoia.org
- **Sin IA**: insignia gris con enlace a la declaración si está disponible
- **Hash de verificación**: visible en ambos casos cuando está disponible

---

### Archivos principales

| Archivo | Propósito |
|---------|-----------|
| `AiDeclarationPlugin.php` | Clase principal: hooks, AJAX handlers, gestión de settings |
| `classes/AiDeclarationHandler.php` | Handler de componente para routing AJAX |
| `classes/DeclaradorApiClient.php` | Cliente HTTP para la API de declarador.usoeticoia.org |
| `classes/DeclarationDataMapper.php` | Mapea los datos del formulario al payload de la API |
| `form/AiDeclarationSettingsForm.php` | Formulario de configuración del plugin |
| `assets/js/declarationWizard.js` | Lógica Vue 2/3 para inyección y validación en el wizard |
| `assets/js/workflowDashboard.js` | Componente Vue 3 del panel editorial (OJS 3.5 dashboard) |
| `assets/css/aiDeclaration.css` | Estilos del formulario y del badge |
| `templates/declarationForm.tpl` | HTML del formulario del wizard (pre-renderizado en servidor) |
| `templates/articleDeclaration.tpl` | Badge en la vista pública del artículo |
| `templates/settingsForm.tpl` | Formulario de ajustes del plugin |
