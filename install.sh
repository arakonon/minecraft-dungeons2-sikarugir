#!/bin/sh
# Baut einen Sikarugir-Wrapper fuer Minecraft Dungeons II (Steam-App 1912410).
#
# Voraussetzungen:
#   - Apple-Silicon-Mac mit Rosetta 2
#   - Sikarugir Creator installiert und mindestens einmal gestartet, sodass unter
#     ~/Library/Application Support/Sikarugir/Template/ ein Template liegt.
#     Daraus kommt auch D3DMetal (Apple verbietet die Weitergabe, deshalb nicht hier im Repo).
#
# Benutzung:  ./install.sh ["Name des Wrappers"]
set -eu

NAME="${1:-Minecraft Dungeons II}"
DEST="$HOME/Applications/Sikarugir/$NAME.app"

# Wine-Engine: CrossOver-26.3-Aenderungen auf Wine 11.17 (dappermint/winecx-gptk),
# auf GitHub-gehosteten Runnern gebaut im Fork arakonon/winecx-gptk.
RUNTIME_URL="https://github.com/arakonon/winecx-gptk/releases/download/runtime-v4.7.5/Libraries.tar.gz"
RUNTIME_SHA256="6d47ceecaad819e1b069600a11cac91cbdf89c2f3d27eb6eb635a27c5601c5c5"

# Ersatz fuer Microsoft Gaming Services (macprotips/Dungeons2_macOS_fix), fest auf einen Commit gepinnt.
XGR_URL="https://raw.githubusercontent.com/macprotips/Dungeons2_macOS_fix/53ee54d6a508596d5e16948198f1152a789a5470/src/xgameruntime.dll"
XGR_SHA256="5e6a2bca3cd1b92c237a5330cbcecd52fa7c6792516b136f9007141eb358bb97"

STEAM_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d -t md2-sikarugir)"
trap 'rm -rf "$WORK"' EXIT

say() { printf '\n==> %s\n' "$1"; }
fetch() {
    curl -fL --progress-bar -o "$2" "$1"
    if [ -n "${3:-}" ]; then
        echo "$3  $2" | shasum -a 256 -c - >/dev/null || { echo "Pruefsumme falsch: $2" >&2; exit 1; }
    fi
}

[ "$(uname -m)" = arm64 ] || { echo "Nur fuer Apple-Silicon-Macs getestet." >&2; exit 1; }
/usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null || { echo "Rosetta fehlt: softwareupdate --install-rosetta" >&2; exit 1; }
TEMPLATE="$(ls -d "$HOME/Library/Application Support/Sikarugir/Template/"Template-*.app 2>/dev/null | sort -V | tail -1)"
[ -n "$TEMPLATE" ] || { echo "Kein Sikarugir-Template gefunden. Sikarugir Creator einmal starten." >&2; exit 1; }
D3DM="$TEMPLATE/Contents/Frameworks/renderer/d3dmetal"
[ -d "$D3DM/external/D3DMetal.framework" ] || { echo "D3DMetal fehlt im Template: $D3DM" >&2; exit 1; }
[ ! -e "$DEST" ] || { echo "Gibt es schon: $DEST" >&2; exit 1; }

say "Downloads"
fetch "$RUNTIME_URL" "$WORK/Libraries.tar.gz" "$RUNTIME_SHA256"
fetch "$XGR_URL" "$WORK/xgameruntime.dll" "$XGR_SHA256"
fetch "$STEAM_URL" "$WORK/SteamSetup.exe"
tar -xzf "$WORK/Libraries.tar.gz" -C "$WORK"
L="$WORK/Libraries"

say "Wrapper aus Template anlegen: $DEST"
mkdir -p "$(dirname "$DEST")"
ditto "$TEMPLATE" "$DEST"
S="$DEST/Contents/SharedSupport"
W="$S/wine"
rm -rf "$W"
ditto "$L/Wine" "$W"
# der Sikarugir-Launcher erwartet diese Datei
echo "wine sikarugir 11.0 (revision 0)" > "$W/version"
P="$DEST/Contents/Info.plist"
plutil -replace CFBundleName -string "$NAME" "$P"
plutil -replace CFBundleIdentifier -string "com.sikarugir.md2.$(date +%s)" "$P"
# Sikarugirs Renderer-Variablen (WINEDLLPATH_D3DMETAL ...) wirken mit dieser Engine nicht
plutil -replace D3DMETAL -integer 0 "$P"
plutil -replace DXVK -integer 0 "$P"
plutil -replace "Debug Mode" -integer 0 "$P"
plutil -replace WINEDEBUG -string "-all" "$P"
plutil -replace "Program Name and Path" -string "/Program Files (x86)/Steam/steam.exe" "$P"
plutil -replace "Program Flags" -string "" "$P"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

say "D3DMetal einbinden"
mkdir -p "$S/stock-d3d" "$S/apple-forwarders" "$S/dxvk-x64"
for f in d3d11 d3d12 dxgi; do cp -p "$W/lib/wine/x86_64-windows/$f.dll" "$S/stock-d3d/"; done
ditto "$D3DM/external/D3DMetal.framework" "$W/lib/external/D3DMetal.framework"
cp -p "$D3DM/external/libd3dshared.dylib" "$W/lib/external/"
# Symlinks, keine Kopien: libd3dshared findet das Framework ueber @loader_path
for f in d3d10 d3d11 d3d12 dxgi; do
    rm -f "$W/lib/wine/x86_64-unix/$f.so"
    ln -s ../../external/libd3dshared.dylib "$W/lib/wine/x86_64-unix/$f.so"
done
cp -p "$D3DM/wine/x86_64-windows/"*.dll "$S/apple-forwarders/"
cp -p "$L/DXVK/x64/"*.dll "$S/dxvk-x64/"
cp -p "$WORK/xgameruntime.dll" "$S/xgameruntime.dll"
cp -p "$HERE/steam-modus.sh" "$S/steam-modus.sh"
chmod +x "$S/steam-modus.sh"

say "Windows-Umgebung anlegen"
# direkt mit der Runtime: der Sikarugir-Launcher (WSS-wineprefixcreate) beendet sich mit ihr nicht
export WINEPREFIX="$S/prefix" WINEDEBUG=-all
"$W/bin/wine" wineboot -i >/dev/null 2>&1
"$W/bin/wineserver" -w
cp -p "$WORK/xgameruntime.dll" "$WINEPREFIX/drive_c/windows/system32/"

say "Steam installieren"
"$W/bin/wine" "$WORK/SteamSetup.exe" /S >/dev/null 2>&1 || true
"$W/bin/wineserver" -k 2>/dev/null || true
CEF="$WINEPREFIX/drive_c/Program Files (x86)/Steam/bin/cef/cef.win64"
[ -d "$CEF" ] || mkdir -p "$CEF"
# steamwebhelper zeichnet mit D3DMetal oder wined3d schwarz, mit DXVK sichtbar
for d in d3d11 d3d10core; do
    "$W/bin/wine" reg add 'HKCU\Software\Wine\AppDefaults\steamwebhelper.exe\DllOverrides' /v "$d" /d native /f >/dev/null 2>&1
done
"$W/bin/wineserver" -w

"$S/steam-modus.sh" login >/dev/null

cat <<EOF

Fertig: $DEST

1. Wrapper per Doppelklick starten, bei Steam anmelden ("Angemeldet bleiben")
   und Minecraft Dungeons II installieren.
2. Steam beenden, dann:
     "$S/steam-modus.sh" spiel
3. Wrapper starten: Steam laeuft unsichtbar und oeffnet das Spiel.
   Beim ersten Start einmal den Microsoft-Code auf microsoft.com/link eingeben.
EOF
