# FluxerMoon

Cliente de Fluxer basado en [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (GPLv3).

## Ramas y remotos

- `upstream` → Moonfin oficial. `origin` → este repo.
- `fluxer` → rama principal de FluxerMoon, construida encima de una versión
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

- Windows: Actions → "FluxerMoon Windows" → Run workflow. El instalador
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
