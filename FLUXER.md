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
| `lib/ui/navigation/app_router.dart` | ruta `/fluxer-login` (y permitirla sin sesión) + rutas bloqueadas |
| `lib/ui/screens/auth/server_select_screen.dart` | botón «Entrar con Fluxer», sin búsqueda en la red ni certificados |
| `lib/ui/screens/auth/add_server_dialog.dart` | directo a la dirección (sin Plex ni Emby Connect) |
| `lib/auth/repositories/session_repository.dart` | mensajes del servidor grandes |
| `lib/app.dart` | arrancar los avisos de FluxerHub (plan, mantenimientos, avisos) |
| `lib/ui/screens/detail/item_detail_screen.dart` | botón «Reportar un problema» |
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
- `fluxer_report_dialog.dart`: «Reportar un problema» en la ficha; llega a
  FluxerHub como solicitud del cliente.

## Versiones

- Cada compilación manual se publica como **pre-release** «Prueba N»: el
  actualizador de la app la ignora.
- Una versión de verdad (la que el actualizador ofrece a los clientes) solo
  se publica cuando lo decide el dueño del proyecto.

## Funciones ocultas

`lib/fluxer/fluxer_features.dart`: un interruptor por función (Plex/Jellyfin/
Silo/Emby Connect, búsqueda en la red, certificados, juegos y After Hours,
logros, libros, Seerr, administración, enlaces de Moonfin). El código de
Moonfin no se borra, solo se ocultan sus entradas, así que las
actualizaciones no dan conflictos. **Al fusionar una versión nueva, revisar
si Moonfin ha añadido funciones nuevas** que convenga ocultar.

## Entrar con Fluxer

`lib/fluxer/app_login/`: la app pide un código a FluxerHub, el cliente lo
acepta en `hub.fluxer.video/portal/vincular` (o pulsa «Entrar con mi cuenta
de Fluxer» y se abre el navegador con el código puesto) y la app entra sola.
Diseño completo: `fluxer/docs/login-fluxerhub.md`. URL del Hub:
`lib/fluxer/fluxer_config.dart`.
