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

## Compilar

- Windows: Actions → "FluxerMoon Windows" → Run workflow. El instalador
  aparece como artefacto `windows-exe`. Un tag `v*` también lo lanza.
