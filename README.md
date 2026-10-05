# Minecraft Dungeons II auf dem Mac mit Sikarugir

Ein Skript, das einen kostenlosen [Sikarugir](https://github.com/Sikarugir-App/Sikarugir)-Wrapper für **Minecraft Dungeons II** (Steam) baut, ohne CrossOver-Lizenz. Getestet auf einem MacBook mit Apple M5 und macOS 27. Im Online-Spiel inklusive Microsoft-Login läuft es gleichwertig zu CrossOver.

> **English summary:** `install.sh` builds a free Sikarugir wrapper for Minecraft Dungeons II on Apple Silicon. It uses a CrossOver-26.3-based Wine runtime (built from public sources), Apple's D3DMetal taken from your local Sikarugir install, and the community `xgameruntime.dll` replacement for Microsoft Gaming Services. The Steam UI renders black with D3DMetal, so `steam-modus.sh` switches between a *login* mode (DXVK, visible UI) and a *play* mode (D3DMetal, Steam hidden, game auto-starts).

## Schnellstart

Voraussetzungen: Apple-Silicon-Mac, Rosetta 2, [Sikarugir Creator](https://github.com/Sikarugir-App/Sikarugir) installiert und einmal gestartet.

```sh
git clone https://github.com/arakonon/minecraft-dungeons2-sikarugir
cd minecraft-dungeons2-sikarugir
./install.sh
```

Danach:

1. `~/Applications/Sikarugir/Minecraft Dungeons II.app` starten, bei Steam anmelden (**Angemeldet bleiben**) und das Spiel installieren.
2. Steam beenden und in den Spiel-Modus wechseln:
   ```sh
   "$HOME/Applications/Sikarugir/Minecraft Dungeons II.app/Contents/SharedSupport/steam-modus.sh" spiel
   ```
3. Wrapper starten. Steam läuft unsichtbar und startet das Spiel.
4. Beim ersten Start öffnet sich der Browser: Den angezeigten Code auf <https://www.microsoft.com/link> eingeben und bestätigen, das Spiel dabei offen lassen. Der Login wird gespeichert.

Wenn Steam dich später abmeldet (das Spiel startet dann nicht mehr), wechselst du mit `steam-modus.sh login` in den Anmelde-Modus, meldest dich an und schaltest danach wieder auf `spiel`.

## Warum es so kompliziert ist

| Problem | Ursache | Lösung |
|---|---|---|
| Spiel stürzt sofort ab („illegal instruction“, Access Violation) | Der Kopierschutz macht direkte NT-Syscalls und wirft C++-Ausnahmen durch System-Code; normales Wine (auch Sikarugirs Wine 11.0 und Wine Staging 11.18) kann das auf macOS nicht | Wine-Runtime mit den CrossOver-Änderungen: [dappermint/winecx-gptk](https://github.com/dappermint/winecx-gptk) (CX 26.3 auf Wine 11.17), auf GitHub-Runnern nachgebaut in [arakonon/winecx-gptk](https://github.com/arakonon/winecx-gptk/releases) |
| Online-Funktionen tot, Microsoft Gaming Services fehlen | Das Spiel braucht `xgameruntime.dll` aus dem Microsoft GDK | [macprotips/Dungeons2_macOS_fix](https://github.com/macprotips/Dungeons2_macOS_fix): Ersatz-DLL mit eigenem Microsoft-Login (Gerätecode) |
| „Zu wenig Videospeicher“ / schwarzes Bild | DirectX 12 lief über Wines eigene Umsetzung, die D3DMetal-Einbindung von Sikarugir greift mit fremden Engines nicht | D3DMetal fest in die Engine eingebunden (`lib/external` und Symlinks, wie von Apple dokumentiert) |
| Steam-Fenster komplett schwarz | Steams Chromium kann mit D3DMetal bzw. wined3d (Vulkan) seine Skia-Shader nicht kompilieren | Anmelde-Modus mit DXVK für `steamwebhelper.exe`; im Spiel-Modus läuft Steam unsichtbar (`-silent -applaunch 1912410`) |

## Was `install.sh` macht

1. Lädt die Runtime (Prüfsumme wird geprüft), die Fix-DLL (fester Commit, Prüfsumme wird geprüft) und den offiziellen Steam-Installer.
2. Kopiert das Sikarugir-Template und ersetzt dessen Wine durch die Runtime.
3. Bindet D3DMetal aus deinem Sikarugir-Template ein. Apple erlaubt keine Weitergabe, deshalb liegt es nicht in diesem Repo.
4. Legt die Windows-Umgebung an, installiert Steam und richtet DXVK für den Steam-Browser ein.
5. Legt `steam-modus.sh` und die benötigten DLL-Sätze (`stock-d3d`, `apple-forwarders`, `dxvk-x64`) in `Contents/SharedSupport/` ab.

Dieses Repo enthält keine Zugangsdaten, Tokens, Steam- oder Spieldateien.

## Wenn der Doppelklick nichts tut

Meist liegen Reste abgebrochener Starts herum. Alles beenden und aufräumen:

```sh
S="$HOME/Applications/Sikarugir/Minecraft Dungeons II.app/Contents/SharedSupport"
WINEPREFIX="$S/prefix" "$S/wine/bin/wineserver" -k
rm -f "$TMPDIR"/xKWx*"Minecraft Dungeons II.app"/lockfile   # Launcher meldet sonst "Secondary run"
rm -rf "$TMPDIR"/winetemp-*                                   # veraltete Wine-Zwischenspeicher ("could not load ntdll.so")
```

Den Wrapper nicht umbenennen, während er läuft. Startet Steam mit `-silent`, bleibt es nach dem Beenden des Spiels unsichtbar im Hintergrund. Vor Änderungen deshalb immer erst `wineserver -k` ausführen.

## Bekannte Eigenheiten

- Im Protokoll des Fixes (`drive_c/xgr.log`) tauchen regelmäßig `begin failed … HttpCallPerform 80070057` auf. Das betrifft nur den Xbox-Freundesstatus und ist harmlos.
- Kopierst du Steam-Anmeldedaten von einem anderen Client (z. B. CrossOver) herüber, werden sie ungültig, sobald du dich dort wieder anmeldest. Melde dich besser direkt im Wrapper an.
- Die Runtime ist x86_64 und braucht Rosetta 2. Apple will Rosetta mit macOS 28 weitgehend einstellen.
- Mojang arbeitet an offiziellem Steam-Deck-Support. Sobald der da ist, läuft das Spiel vermutlich auch mit normalem Wine.

## Danke an

- [dappermint/winecx-gptk](https://github.com/dappermint/winecx-gptk) für die GPTK-fähige CrossOver-Runtime
- [macprotips/Dungeons2_macOS_fix](https://github.com/macprotips/Dungeons2_macOS_fix) für den Gaming-Services-Ersatz
- [Sikarugir](https://github.com/Sikarugir-App/Sikarugir), [CodeWeavers](https://www.codeweavers.com/crossover/source) (Quellcode), [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS)

Inoffiziell, ohne Verbindung zu Mojang, Microsoft, Valve, Apple oder CodeWeavers.
