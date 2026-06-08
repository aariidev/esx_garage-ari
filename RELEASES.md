# Releases

## v1.16.1-ari

### Resumen
- Fix de la barra de combustible tapada por el botón de acción en las tarjetas de vehículo.
- Ajuste de layout flex: el contenido ya no se comprime y el footer queda siempre debajo de las métricas.

### Bug Fixes
- **Fuel bar overlap:** Eliminado `min-height: 0` y `flex: 1 1 auto` en `.vcard-content` que comprimían las barras de condición/combustible.
- **Card height:** Las tarjetas con combustible usan `.has-fuel` y altura mínima adecuada; el botón vive en `.vcard-footer` sin solaparse.
- **List mode:** Métricas con `flex-shrink: 0` y alineación `stretch` en vista compacta (6+ vehículos).

### Archivos clave
- `nui/css/app.css`
- `nui/js/app.js`
- `nui/ui.html`
- `fxmanifest.lua`

### Upgrade
1. Sustituye `nui/` y `fxmanifest.lua`.
2. `restart ari_garage`.

---

## v1.16.0-ari

### Resumen
- Rediseño completo de la NUI con Plus Jakarta Sans, iconos Lucide y glassmorphism.
- Vista compacta en lista horizontal cuando hay más de 5 vehículos.
- Fix del botón desaparecido con 6+ coches (`data-index` + `state.renderedVehicles`).

### UI
- Sidebar + grid de cards con stats en grid de 3 columnas.
- Footer fijo por tarjeta con borde superior.
- Preview local: `nui/ui.html?preview=1`

### Archivos clave
- `nui/ui.html`, `nui/css/app.css`, `nui/js/app.js`
- `fxmanifest.lua`

---

## v1.15.3-ari

### Resumen
- Fix del error `TranslateCap` en el menú admin (`/admingarage`) que causaba crashes al buscar vehículos por matrícula.
- Mejora en el renderizado de la UI cuando hay muchos vehículos.
- **Nuevo:** Garajes comunicados — todos los garajes ahora muestran TODOS los vehículos del jugador.

### Bug Fixes
- **Fix TranslateCap Error:** Agregadas funciones `safeTC()` y `tf()` en `client/main.lua` y `client/admin.lua` para manejar traducciones nil de forma segura y evitar el error `bad argument #1 to 'format' (no value)`.
- **Fix UI Layout:** Añadido `height: 100%` al área de contenido en `nui/css/app.css` para mejorar el scroll cuando hay muchos vehículos.
- **Fix SQL Dependency:** Actualizado de `@mysql-async` a `@oxmysql` en `fxmanifest.lua` para mayor compatibilidad.

### Nuevas Funciones
- **Garajes Comunicados:** Modificada la consulta SQL en `server/main.lua` (`getVehiclesInParking`) para mostrar TODOS los vehículos almacenados (`stored = 1`) sin importar el garaje original donde se guardaron.
- Ahora el jugador puede ver y extraer sus vehículos desde CUALQUIER garaje configurado.

### Archivos clave
- `client/main.lua` — función `safeTC()` + lógica de garajes comunicados
- `client/admin.lua` — funciones `t()` y `tf()` seguras
- `nui/css/app.css` — fix layout
- `server/main.lua` — SQL sin restricción por parking

### Upgrade
1. Sustituye los archivos: `client/main.lua`, `client/admin.lua`, `nui/css/app.css`, `server/main.lua`, `fxmanifest.lua`
2. No hace falta tocar la base de datos.
3. `restart ari_garage`.

### Compatibilidad
- 100% compatible con eventos, callbacks y exports de 1.15.2-ari. No hay breaking changes.

---

## v1.15.2-ari

### Resumen
- Pulido visual fuerte de la NUI: panel glassy real con blur, animaciones nuevas, micro-interacciones por todas partes.
- Atajos de teclado dentro del menú y botón de refrescar.
- Limpieza profunda del Lua: una sola función para el coste de liberación, menos consultas SQL, `Config.ImpoundOnEmpty` por fin hace algo.
- **Nuevo:** version checker conectado a GitHub (`aariidev/esx_garage-ari`) que avisa por consola cuando hay una versión más nueva publicada.

### UI
- Panel con `backdrop-filter` blur + saturación, sombra y borde más limpios.
- Indicador "live" pulsando al lado del título de la pestaña.
- Mini-estadísticas en el sidebar: total de vehículos y condición media (con contador animado).
- Pista de atajos visible en el sidebar (`/`, `1/2`, `Esc`).
- Botón de refrescar en la topbar.
- Barras de condición y combustible con relleno animado y brillo (shimmer).
- "Orb" de luz que sigue al cursor en cada tarjeta (parallax sutil).
- Tarjetas con shine sweep al pasar por encima del botón.
- Transición animada al cambiar de pestaña.
- Partículas flotantes muy sutiles de fondo (acento).
- Insignias del sidebar con bump cuando el contador cambia.
- Empty-state con icono flotante.
- Respeta `prefers-reduced-motion`.
- **Fix:** panel mucho menos opaco (`--bg-panel` 0.86 → 0.55, `--bg-sidebar` 0.92 → 0.62) y blur subido a 36px. Antes en sitios oscuros del mapa parecía un cuadrado negro tapando el juego; ahora la escena se ve detrás como debe.
- Reglas extra de `background: transparent !important` en `:root`/`html`/`body`/pseudoelementos para que ningún tema/extensión meta un backdrop por accidente.

### UX / NUI
- `/` enfoca la búsqueda.
- `1` / `2` cambian entre garaje e impound.
- `R` refresca la lista actual.
- `Esc` cierra (igual que antes).
- Nuevo callback NUI `refresh` que reabre la vista actual sin cerrar el menú.

### Server (Lua)
- Nueva `calculateReleaseCost(impound, props)` como única fuente del coste de liberación. `decodeVehicleRows` y `computeReleaseData` ya no duplican fórmulas.
- `setImpound` ya no hace un `SELECT` extra para notificar al dueño: usamos el dato que ya teníamos.
- `Config.ImpoundOnEmpty` ahora sí: si guardas un coche con `fuelLevel <= 0`, queda directamente en el primer impound configurado.
- `getPlayerFromSource` y compañía con guards extra contra `nil` (ESX no cargado, jugador desconectado en mitad del flujo).
- `checkMoney` siempre devuelve `hasMoney` (ya no queda `nil` en algunos paths).
- `getVehiclesInPound` aplica `FreeRelease` también en cada vehículo del listado, no solo en el meta.

### Update checker (GitHub)
- Nuevo `server/version_check.lua`: en el arranque del recurso consulta `api.github.com/repos/aariidev/esx_garage-ari/releases/latest` y compara con la versión local de `fxmanifest.lua`.
- Mensajes en consola con códigos de color de FiveM:
  - Verde si estás al día.
  - Amarillo + link si hay versión nueva.
  - Verde "AHEAD" si tu copia es más nueva que la publicada (caso típico mientras desarrollas).
- Configurable en `Config.VersionCheck` (`Enabled`, `Owner`, `Repo`, `Endpoint`, `Verbose`, `IntervalMinutes`).
- Si no hay releases publicadas, cae automáticamente a `/tags`.
- Comando manual desde la consola del server: `ari_garage_version`.
- Añadido `repository 'https://github.com/aariidev/esx_garage-ari'` en `fxmanifest.lua` (lo usan algunas tools de FiveM como `txAdmin` para mostrar el origen del recurso).

### Client (Lua)
- `OpenGarageMenu` y `OpenImpoundMenu` declarados arriba para poder usarlos desde callbacks anteriores.
- Se guarda `lastOpenContext` para que el botón de refrescar reabra exactamente el mismo garaje/impound.
- `lastOpenContext` se limpia al cerrar el menú.
- `spawnOwnedVehicle` con guard contra payload incompleto.

### Archivos clave
- `nui/css/app.css`, `nui/js/app.js`, `nui/ui.html`
- `server/main.lua`, `client/main.lua`
- `fxmanifest.lua`, `config.lua`

### Upgrade
1. Sustituye los archivos de la carpeta `nui/`, `server/main.lua`, `client/main.lua`, `config.lua` y `fxmanifest.lua`.
2. No hace falta tocar la base de datos (la migración de 1.15.0 sigue siendo válida).
3. `restart ari_garage`.

### Compatibilidad
- 100% compatible con eventos, callbacks y exports de 1.15.0-ari. No hay breaking changes.

---

## v1.15.0-ari

### Resumen
- Refactor completo de garaje y depósito.
- NUI renovada con look morado neón.
- SQL más claro, con estados de vehículo consistentes e índices nuevos.
- Textos en español más cortos y con más personalidad.

### Novedades
- Estado formal del vehículo:
  - `0` = fuera
  - `1` = guardado
  - `2` = depositado
- El listado de impound ya no mezcla coches fuera con coches en depósito.
- `VehicleFilter` ya filtra los vehículos por tipo.
- `FreeRelease`, `AllowedJobs` y `AllowedGrades` ahora sí afectan la liberación del depósito.
- El coste de sacar un vehículo del depósito puede variar según daño con `Config.ImpoundDamageMult`.
- La UI muestra mejor el estado, la condición y el coste de liberación.
- Color por defecto actualizado a morado neón.

### UI
- Fondo limpio sin bloque negro detrás del panel.
- Sidebar y tarjetas rehechas para una lectura más clara.
- Botones y badges con mejor contraste.
- Preview local disponible en:
  - `file:///C:/Users/ari/Desktop/esx_garage-ari/nui/ui.html?preview=1`

### SQL
- Migración rehecha en `ari_garage.sql`.
- Normalización de `parking` y `pound`.
- Nuevos índices:
  - `idx_owned_vehicles_owner_stored_parking`
  - `idx_owned_vehicles_owner_stored_pound`
  - `idx_owned_vehicles_owner_plate`

### Archivos clave
- `server/main.lua`
- `client/main.lua`
- `nui/css/app.css`
- `nui/js/app.js`
- `locales/es.lua`
- `ari_garage.sql`

### Upgrade
1. Sustituye el recurso por esta versión.
2. Ejecuta `ari_garage.sql` en tu base de datos.
3. Reinicia el recurso:
   - `restart esx_garage-ari`

### Nota
- Se mantiene compatibilidad con los eventos, callbacks y exports ya existentes del recurso.
