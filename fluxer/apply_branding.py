#!/usr/bin/env python3
"""Aplica la marca de FluxerPlayer sobre el código oficial de Moonfin.

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


# --- Versión propia de FluxerPlayer (fluxer/version.json) -------------------
# pubspec.yaml version = <version>+<número de compilación>. El número sube en
# cada compilación (FLUXER_BUILD_NUMBER, en CI el número de ejecución): Android
# lo necesita para aceptar una actualización. En una etiqueta v*, la etiqueta
# debe coincidir con la versión.

import os  # noqa: E402

VERSION = json.loads((ROOT / "fluxer" / "version.json").read_text(encoding="utf-8"))
build_number = os.environ.get("FLUXER_BUILD_NUMBER", "1").strip() or "1"
if not re.fullmatch(r"\d+\.\d+\.\d+", VERSION["version"]):
    errors.append(f"version.json: versión no válida {VERSION['version']!r} (debe ser X.Y.Z)")
if not build_number.isdigit():
    errors.append(f"FLUXER_BUILD_NUMBER no es un número: {build_number!r}")
tag = os.environ.get("FLUXER_RELEASE_TAG", "").strip()
if tag and tag != f"v{VERSION['version']}":
    errors.append(f"la etiqueta {tag} no coincide con version.json ({VERSION['version']})")
sub("pubspec.yaml", [
    (r"(?m)^version:\s*\S+", f"version: {VERSION['version']}+{build_number}"),
])

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

# --- Enlaces fluxerplayer:// en vez de moonfin:// (no chocan con Moonfin) ---

scheme = CFG["urlScheme"]
sub("windows/runner/main.cpp", [
    (r'L"Software\\\\Classes\\\\moonfin"', f'L"Software\\\\\\\\Classes\\\\\\\\{scheme}"'),
    (r'L"URL:Moonfin"', f'L"URL:{NAME}"'),
])
sub("build-windows.ps1", [
    (r'Subkey: "Software\\Classes\\moonfin"', f'Subkey: "Software\\\\Classes\\\\{scheme}"'),
])
sub("lib/data/services/deep_link_service.dart", [
    (r"uri\.scheme != 'moonfin'", f"uri.scheme != '{scheme}'"),
])
sub("android/app/src/main/AndroidManifest.xml", [
    (r'android:scheme="moonfin"', f'android:scheme="{scheme}"'),
])

# --- Actualizador: buscar versiones en NUESTRO repo, no en el de Moonfin -----

repo = CFG["updatesGithubRepo"]
sub("lib/data/services/app_update_service.dart", [
    (r"/repos/Moonfin-Client/Moonfin-Core/releases/latest", f"/repos/{repo}/releases/latest"),
    (r"https://github\.com/Moonfin-Client/Moonfin-Core/releases/latest",
     f"https://github.com/{repo}/releases/latest"),
    (r"'MoonfinUpdateChecker/", f"'{NAME}UpdateChecker/"),
])

# --- "Acerca de": código fuente y licencias, a NUESTRO repo (lo exige la GPL) -

src = CFG["sourceCodeUrl"].rstrip("/")
sub("lib/ui/screens/settings/panel/about_category_screen.dart", [
    (r"'https://github\.com/Moonfin-Client/Moonfin-Core/blob/main/LICENSE'", f"'{src}/blob/fluxer/LICENSE'"),
    (r"'https://github\.com/Moonfin-Client/Moonfin-Core'", f"'{src}'"),
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

# --- Textos propios (fluxer/branding/strings.json) --------------------------
# Sustituyen el texto de una clave en todos los idiomas: 'es' en es_*, 'en' en
# el resto. Si el idioma no tiene la clave (sale en inglés), se añade.

overrides = {
    k: v for k, v in json.loads(
        (ROOT / "fluxer" / "branding" / "strings.json").read_text(encoding="utf-8")
    ).items() if not k.startswith("_")
}
en_keys = set(json.loads((ROOT / "lib" / "l10n" / "app_en.arb").read_text(encoding="utf-8")))
for key in overrides:
    if key not in en_keys:
        errors.append(f"strings.json: la clave {key!r} ya no existe en app_en.arb")
for arb in arbs:
    raw = arb.read_text(encoding="utf-8")
    m = re.search(r'\n( +)"', raw)
    top = m.group(1) if m else "    "
    lang = arb.stem.removeprefix("app_").split("_")[0]
    for key, texts in overrides.items():
        value = json.dumps(texts["es"] if lang == "es" else texts["en"], ensure_ascii=False)
        line = re.compile(r'^' + top + re.escape(json.dumps(key)) + r':\s*".*?"(?=\s*,?\s*$)', re.M)
        new_line = top + json.dumps(key) + ": " + value
        if line.search(raw):
            raw = line.sub(lambda _: new_line, raw, count=1)
        else:
            raw = re.sub(r'(^' + top + r'"@@locale":[^\n]*\n)', lambda mm: mm.group(1) + new_line + ",\n", raw, count=1, flags=re.M)
    arb.write_text(raw, encoding="utf-8")

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

print(f"Marca '{NAME}' {VERSION['version']}+{build_number} aplicada ({changed_en} textos en inglés, {len(arbs)} idiomas, {copied} imágenes).")
