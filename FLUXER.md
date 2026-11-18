# FluxerPlayer

Cliente de Fluxer basado en [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (GPLv3).

## Ramas y remotos

- `upstream` → Moonfin oficial. `origin` → este repo.
- `fluxer` → rama principal de FluxerPlayer, construida encima de una versión
  publicada de Moonfin (ahora `3.1.0`).

## Actualizar con una versión nueva de Moonfin

```sh
git fetch upstream --tags
git merge <tag>          # p. ej. 3.2.0, nunca upstream/main
git push
```

## Reglas para que las actualizaciones no rompan nada

- El código propio va en ficheros nuevos (`lib/fluxer/`, `fluxer/`,
  `.github/workflows/fluxer-*.yml`). Se tocan lo mínimo los ficheros
  oficiales, y cada cambio en ellos lleva el comentario `// FLUXER:`.
- Los workflows oficiales de Moonfin no se editan: están desactivados desde
  GitHub (`gh workflow disable`).

## Marca (nombre, instalador, textos)

- Se configura en `fluxer/branding.json` (nombre visible, editor, GUID del
  instalador, URL del código fuente).
- `fluxer/apply_branding.py` la aplica en CI antes de compilar. Los ficheros
  oficiales no se modifican en git, así que la marca nunca da conflictos.
- Si una versión nueva de Moonfin cambia un texto que el script busca, la
  compilación falla con un error que dice qué fichero revisar.
- Probarlo en local: `python3 fluxer/apply_branding.py`, y deshacerlo con
  `git checkout -- windows build-windows.ps1 lib assets web`.

## Compilar

- Windows: Actions → "FluxerPlayer Windows" → Run workflow. El instalador
  aparece como artefacto `windows-exe`. Un tag `v*` también lo lanza.

## Iconos e imágenes

Copiar la imagen nueva en `fluxer/branding/overlay/` con la MISMA ruta que el
fichero oficial que sustituye (mismo nombre y formato). Principales:

| Fichero oficial | Dónde se ve |
|---|---|
| `windows/runner/resources/app_icon.ico` | Icono del .exe, barra de tareas e instalador (Windows) |
| `assets/icons/moonfin.png` (512×512) | Logo dentro de la app |
| `assets/icons/moonfin_logo.svg` | Logo vectorial dentro de la app |
| `assets/icons/app_icon.png` | Icono de la app |
| `web/favicon.png` (64×64), `web/icons/*` | Solo versión web |

## Ficheros oficiales modificados (revisar al fusionar)

Todo lo demás de FluxerPlayer vive en ficheros propios (`lib/fluxer/`, `fluxer/`,
`.github/workflows/fluxer-*.yml`). Cada línea tocada lleva `// FLUXER:`
(`git grep -n "FLUXER:"` las lista todas).

| Fichero | Qué |
|---|---|
| `lib/ui/navigation/app_router.dart` | ruta `/fluxer-login` (y permitirla sin sesión), rutas bloqueadas y, en modo solo Fluxer, las pantallas de entrar de Moonfin llevan a la de Fluxer |
| `lib/ui/screens/auth/server_select_screen.dart` | «Entrar/Continuar con Fluxer» arriba y principal, «Añadir otro servidor» secundario, sin búsqueda en la red ni certificados |
| `lib/ui/widgets/user_menu_dialog.dart` | «Cambiar de usuario»: solo usuarios de Fluxer, sin «Añadir usuario» ni «Seleccionar servidor» |
| `lib/ui/screens/auth/login_screen.dart` | en un servidor de Fluxer, «Entrar con Fluxer» (sin contraseña) encima del formulario |
| `lib/ui/screens/auth/add_server_dialog.dart` | directo a la dirección (sin Plex ni Emby Connect) |
| `lib/auth/repositories/session_repository.dart` | mensajes del servidor grandes |
| `lib/app.dart` | arrancar los avisos de FluxerHub (plan, mantenimientos, avisos) |
| `lib/ui/screens/detail/item_detail_screen.dart`, `lib/ui/screens/playback/video_player_screen.dart` | botón «Reportar un problema» |
| `lib/ui/screens/settings/settings_side_panel.dart` | sección «Mi cuenta Fluxer» (además de lo oculto) |
| `lib/preference/user_preferences.dart` (`get`), `lib/ui/widgets/navigation_layout.dart`, `lib/ui/screens/settings/panel/navigation_category_screen.dart` | opciones fijadas en cuentas de Fluxer (barra lateral) |
| `lib/ui/screens/settings/panel/home_screen_category_screen.dart`, `panel/settings_search_index.dart` | sin la sección «Barra de medios» en cuentas de Fluxer |
| `lib/data/repositories/media_bar_repository.dart` | barra de inicio con «Tendencias de hoy» (Hub `api/app/trending`) en cuentas de Fluxer |
| `lib/util/platform_detection.dart` (`supportsOfflineDownloads`) | sin descargas ni modo sin conexión |
| `lib/data/services/push_messaging_service.dart` | sin notificaciones push de Moonfin (Firebase) |
| `lib/ui/screens/admin/admin_nav.dart` | sin administración |
| `lib/util/signed_in_server_features.dart`, `lib/data/services/plugin_sync_service.dart` | sin Seerr |
| `lib/data/services/achievements_service.dart` | sin logros |
| `lib/ui/screens/settings/settings_side_panel.dart` (+ `panel/account_screen.dart`, `panel/about_category_screen.dart`, `panel/settings_search_index.dart`) | sin certificados, sin enlaces de Moonfin, sin After Hours |

## FluxerHub desde la app

Al entrar con Fluxer la app recibe también un token propio del Hub
(`lib/fluxer/hub/fluxer_hub_client.dart`, almacén seguro) que solo abre
`/api/app/*`: estado del plan, avisos y reportar un problema.
- `fluxer_hub_watcher.dart`: al arrancar y cada 30 min, avisa del plan
  (caducado o caduca en ≤5 días sin renovación automática; una vez al día),
  mantenimientos (una vez cada uno) y avisos globales de ventana.
- `fluxer_report_dialog.dart`: «Reportar un problema» en la ficha y en el
  reproductor; llega a FluxerHub como solicitud del cliente (con el
  diagnóstico adjunto si el cliente lo graba).
- `fluxer_account_screen.dart`: Ajustes → «Mi cuenta Fluxer» (plan, renovar
  —QR en la tele—, servidor, Invita y gana, diagnóstico, desvincular).
- El vigilante avisa también de incidencias del servidor (cada 6 h).
- `fluxer_portal.dart`: abre el portal ya con la sesión iniciada (enlace de un
  solo uso del Hub, `api/app/portal-link`): navegador en ordenador y móvil,
  QR en la tele. Lo usan «Renovar», el aviso del plan y el soporte.

## Versiones

FluxerPlayer tiene **sus propios números** (`fluxer/version.json`:
`version`, y `moonfinBase` = versión de Moonfin sobre la que está montada).
Se aplican al compilar (`pubspec.yaml` → `version: X.Y.Z+N`, N = número de
compilación, sube solo en cada ejecución de CI); el pubspec de Moonfin no se
toca en git.

- No se publican compilaciones de prueba. Lanzar «FluxerPlayer Release» a
  mano solo compila (artefactos en la ejecución), sin publicar.
- **Versión para clientes** (solo cuando lo decide el dueño del proyecto):
  1. Subir `version` en `fluxer/version.json` (y `moonfinBase` si se ha
     fusionado una versión de Moonfin).
  2. Añadir su sección `## X.Y.Z — título` en `CHANGELOG-FLUXER.md`: nuestros
     cambios + resumen de lo que trae Moonfin («De Moonfin»).
  3. `git tag vX.Y.Z && git push origin vX.Y.Z`. CI compila y publica la
     versión con esas notas; la app la ofrece al abrirse (como mucho una vez
     al día; en Windows la descarga e instala sola).

## Android (móvil y tele)

Una etiqueta compila también `FluxerPlayer_Android_vX.Y.Z.apk` (móviles) y
`FluxerPlayer_AndroidTV_vX.Y.Z.apk` (Android TV, Google TV, Fire TV).
Identificador `video.fluxer.player` (convive con Moonfin), sin Firebase.
Iconos y banner de la tele en `fluxer/branding/overlay/android/`.

**Clave de firma**: `/home/devilgaia/projects/fluxerplayer-secrets/` (fuera
del repo; hacer copia en lugar seguro). Va en los secretos del repo:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_TYPE` (PKCS12),
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`
(fluxerplayer). **Si se pierde, no se puede actualizar la app instalada**:
habría que desinstalar e instalar de nuevo.

## Firma del instalador (pendiente)

Sin firma, Windows enseña el aviso de SmartScreen. El workflow ya está
preparado para firmar con **SignPath** (gratis para proyectos de código
abierto, lo usa Moonfin); se activa solo cuando existen en el repo:
- secreto `SIGNPATH_API_TOKEN` y variable `SIGNPATH_ORGANIZATION_ID`;
- opcionales: `SIGNPATH_PROJECT_SLUG` (`fluxerplayer`),
  `SIGNPATH_SIGNING_POLICY` (`release-signing`),
  `SIGNPATH_ARTIFACT_CONFIGURATION` (`windows-installer`).

Hay que solicitarlo en signpath.org (SignPath Foundation) como titular del
proyecto. Alternativas de pago: Azure Artifact Signing o un certificado
de firma de código. Ojo: con cualquier certificado nuevo, SmartScreen puede
seguir avisando las primeras semanas, hasta que el instalador gana
reputación con las descargas.

## Solo Fluxer

`FluxerFeatures.fluxerOnly` (true): se entra siempre con la cuenta de Fluxer.
Las pantallas de entrar de Moonfin (elegir servidor, contraseña, usuarios
del servidor, Emby Connect, Plex) redirigen a `/fluxer-login`
(`fluxerAuthRedirect`). Si la app ya está vinculada, ahí sale «Continuar con
mi cuenta de Fluxer» (sesión nueva desde el Hub, sin contraseña).

## Opciones fijadas en cuentas de Fluxer

`lib/fluxer/fluxer_locks.dart`: con una cuenta de Fluxer (entró con «Entrar
con Fluxer», `FluxerServers`), esas opciones valen lo que fija Fluxer y en
Ajustes salen como «la fija Fluxer». Con cualquier otra cuenta, como en
Moonfin. Ahora: barra de navegación = lateral izquierda; tasa de bits = 200
Mbps; sin TV en vivo directo; barra de medios siempre activa con su estilo
por defecto y «Tendencias de hoy» (su sección no sale en Ajustes:
`fluxerHidesSettingsSection`). Para fijar otra:
añadir su clave y valor a `_locked` (y, si tiene pantalla en Ajustes,
enseñarla como fijada).

## Funciones ocultas

`lib/fluxer/fluxer_features.dart`: un interruptor por función (Plex/Jellyfin/
Silo/Emby Connect, búsqueda en la red, certificados, juegos y After Hours,
logros, libros, Seerr, administración, enlaces de Moonfin, descargas,
notificaciones push de Moonfin). El código de
Moonfin no se borra, solo se ocultan sus entradas, así que las
actualizaciones no dan conflictos. **Al fusionar una versión nueva, revisar
si Moonfin ha añadido funciones nuevas** que convenga ocultar.

## Entrar con Fluxer

`lib/fluxer/app_login/`: la app pide un código a FluxerHub, el cliente lo
acepta en `hub.fluxer.video/portal/vincular` (o pulsa «Entrar con mi cuenta
de Fluxer» y se abre el navegador con el código puesto) y la app entra sola.
Diseño completo: `fluxer/docs/login-fluxerhub.md`. URL del Hub:
`lib/fluxer/fluxer_config.dart`.
