#!/bin/sh
# Schaltet einen Minecraft-Dungeons-II-Wrapper zwischen zwei Modi um.
#
#   login  Steam-Oberflaeche sichtbar (Wine-eigene dxgi + DXVK fuer steamwebhelper).
#          Nur zum Anmelden noetig.
#   spiel  D3DMetal fuer das Spiel; Steam startet unsichtbar und oeffnet das Spiel.
#
# Liegt in <Wrapper>.app/Contents/SharedSupport/ und arbeitet relativ dazu.
set -e
S="$(cd "$(dirname "$0")" && pwd)"
APP="$(cd "$S/../.." && pwd)"
DLLS="$S/wine/lib/wine/x86_64-windows"
STEAM="$S/prefix/drive_c/Program Files (x86)/Steam"
GAME="$STEAM/steamapps/common/Minecraft Dungeons II"
export WINEPREFIX="$S/prefix" WINEDEBUG=-all

"$S/wine/bin/wineserver" -k 2>/dev/null || true
sleep 2

case "$1" in
  login)
    cp -p "$S/stock-d3d/"*.dll "$DLLS/"
    rm -f "$DLLS/nvapi64.dll" "$DLLS/nvngx.dll" "$DLLS/atidxx64.dll"
    cp -p "$S/dxvk-x64/"*.dll "$STEAM/bin/cef/cef.win64/"
    plutil -replace "Program Flags" -string "" "$APP/Contents/Info.plist"
    ;;
  spiel)
    cp -p "$S/apple-forwarders/"*.dll "$DLLS/"
    # Fix nach Spiel-Download/-Update in beide Spielordner legen
    if [ -f "$S/xgameruntime.dll" ] && [ -d "$GAME/Dungeons/Binaries/Win64" ]; then
      cp -p "$S/xgameruntime.dll" "$GAME/xgameruntime.dll"
      cp -p "$S/xgameruntime.dll" "$GAME/Dungeons/Binaries/Win64/xgameruntime.dll"
    fi
    plutil -replace "Program Flags" -string "-silent -applaunch 1912410" "$APP/Contents/Info.plist"
    ;;
  *)
    echo "Benutzung: $0 login|spiel" >&2
    exit 1
    ;;
esac
echo "Modus: $1. Jetzt den Wrapper per Doppelklick starten."
