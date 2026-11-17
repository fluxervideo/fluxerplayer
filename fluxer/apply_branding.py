#!/usr/bin/env python3
"""Aplica la marca de FluxerMoon sobre el código oficial de Moonfin.

Se ejecuta en CI justo antes de compilar, sobre un checkout limpio. Los
ficheros oficiales NO se modifican en git, así que fusionar versiones nuevas
de Moonfin nunca da conflictos por la marca.

Si Moonfin cambia alguno de los textos que buscamos, el script falla con un
error que dice qué fichero y qué patrón, en vez de compilar con la marca a
medias.

Uso:  python fluxer/apply_branding.py
Para deshacerlo en local:  git checkout -- windows build-windows.ps1 lib assets web
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CFG = json.loads((ROOT / "fluxer" / "branding.json").read_text(encoding="utf-8"))
NAME = CFG["appName"]

errors: list[str] = []


def read(rel: str) -> str:
    with open(ROOT / rel, encoding="utf-8", newline="") as f:
        return f.read()


def write(rel: str, text: str) -> None:
    with open(ROOT / rel, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def sub(rel: str, rules: list[tuple[str, str]]) -> None:
    """Aplica reemplazos regex; cada patrón debe encontrarse al menos una vez."""
    text = read(rel)
    for pattern, repl in rules:
        text, n = re.subn(pattern, repl, text)
        if n == 0:
            errors.append(f"{rel}: no se encontró el patrón {pattern!r}")
    write(rel, text)


# --- Windows: ventana, propiedades del .exe e instalador -------------------

sub("windows/runner/main.cpp", [
    (r'window\.Create\(L"Moonfin"', f'window.Create(L"{NAME}"'),
])

sub("windows/runner/Runner.rc", [
    (r'"CompanyName", "org\.moonfin"', f'"CompanyName", "{CFG["companyId"]}"'),
    (r'"FileDescription", "Moonfin"', f'"FileDescription", "{NAME}"'),
    (r'"ProductName", "Moonfin"', f'"ProductName", "{NAME}"'),
    (r'Copyright \(C\) (\d+) org\.moonfin\.', rf'Copyright (C) \1 {CFG["publisher"]}.'),
])

prefix = CFG["installerPrefix"]
sub("build-windows.ps1", [
    (r'#define MyAppName "Moonfin"', f'#define MyAppName "{NAME}"'),
    (r'#define MyAppPublisher "Moonfin"', f'#define MyAppPublisher "{CFG["publisher"]}"'),
    # AppId distinto: así no sobrescribe ni desinstala un Moonfin oficial.
    (r'AppId=\{\{[0-9A-Fa-f-]+\}', f'AppId={{{{{CFG["windowsInstallerAppId"]}}}'),
    (r'DefaultDirName=\{autopf\}\\Moonfin', f'DefaultDirName={{autopf}}\\\\{NAME}'),
    (r'"Moonfin_WindowsARM64_v', f'"{prefix}_WindowsARM64_v'),
    (r'"Moonfin_Windows_v', f'"{prefix}_Windows_v'),
])

# --- Nombre de cliente que ven Emby/Jellyfin (y la lista de dispositivos) ---

for rel in ("lib/di/injection.dart", "lib/playback/device_profile_builder.dart"):
    sub(rel, [(r"'Moonfin(?=[ ']|$)", f"'{NAME}")])

# --- Textos de la interfaz (todos los idiomas) ------------------------------
# Se regeneran a Dart en cada build (flutter: generate: true en pubspec).

# Textos que deben seguir diciendo "Moonfin": hablan del plugin de servidor,
# del desarrollador original o de una carpeta que el código sigue llamando así.
KEEP_KEYS = {
    "downloadsVisibleToOtherApps",
    "saveToDownloadsFolderDescription",
    "settingsSupportMoonfin",
    "settingsSupportMoonfinSubtitle",
    "savedThemesDescription",
    "themeEditorSubtitle",
}
WORD = re.compile(r"\bMoonfin\b")

arbs = sorted((ROOT / "lib" / "l10n").glob("*.arb"))
if not arbs:
    errors.append("lib/l10n: no hay ficheros .arb")
changed_en = 0
for arb in arbs:
    # Reemplazo en el texto, línea a línea (no se reescribe el JSON entero:
    # los .arb tienen claves duplicadas y escapes \uXXXX que hay que conservar).
    raw = arb.read_text(encoding="utf-8")
    m = re.search(r'\n( +)"', raw)
    top = m.group(1) if m else "    "  # sangría de las claves de primer nivel
    entry = re.compile(r'^(' + top + r'"([^"@][^"]*)":\s*")(.*)("\s*,?\s*)$', re.M)

    def fix(mo: re.Match) -> str:
        global changed_en
        head, key, value, tail = mo.groups()
        if key == "sourceCodeUrl":
            return head + CFG["sourceCodeUrl"] + tail  # GPL: enlazar a NUESTRO código
        if key in KEEP_KEYS or not WORD.search(value):
            return mo.group(0)
        if arb.name == "app_en.arb":
            changed_en += 1
        return head + WORD.sub(NAME, value) + tail

    arb.write_text(entry.sub(fix, raw), encoding="utf-8")
if changed_en == 0:
    errors.append("lib/l10n/app_en.arb: no se cambió ningún texto")

# --- Imágenes e iconos ------------------------------------------------------
# Todo lo que haya en fluxer/branding/overlay/ se copia encima del repo con la
# misma ruta (p. ej. overlay/windows/runner/resources/app_icon.ico).
# Solo se permite sustituir ficheros que existan: si Moonfin mueve o renombra
# uno, falla en vez de dejar el icono viejo sin avisar.
overlay = ROOT / "fluxer" / "branding" / "overlay"
copied = 0
for src in sorted(p for p in overlay.rglob("*") if p.is_file()):
    rel = src.relative_to(overlay)
    dst = ROOT / rel
    if not dst.exists():
        errors.append(f"overlay/{rel.as_posix()}: no existe {rel.as_posix()} en el repo")
        continue
    dst.write_bytes(src.read_bytes())
    copied += 1

if errors:
    print("ERROR aplicando la marca (¿Moonfin cambió estos ficheros?):", file=sys.stderr)
    for e in errors:
        print("  - " + e, file=sys.stderr)
    sys.exit(1)

print(f"Marca '{NAME}' aplicada ({changed_en} textos en inglés, {len(arbs)} idiomas, {copied} imágenes).")
