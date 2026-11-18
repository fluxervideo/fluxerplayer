# FluxerPlayer

Cliente de Fluxer basado en [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (GPLv3).

- Rama `fluxer`, construida sobre una versión publicada de Moonfin.
- El código propio está en `lib/fluxer/`, `fluxer/` y
  `.github/workflows/fluxer-release.yml`.
- Los cambios en archivos de Moonfin son mínimos y van marcados con
  `// FLUXER:`.
- La marca (nombre, iconos, textos) la aplica `fluxer/apply_branding.py` al
  compilar.
- Cada etiqueta `vX.Y.Z` compila y publica Windows y Android; las notas salen
  de `CHANGELOG-FLUXER.md`.
