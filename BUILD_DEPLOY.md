# Build und Deployment – CamperControl für Ford SYNC 3

Diese Anleitung beschreibt den V2-only-Releaseweg für CamperControl 3.12.0.
V1-QML, V1-Auswahl und alte Fahrzeugassets sind nicht enthalten.

> **Zurückgezogene Pakete:** Der Kandidat aus Commit
> `abf7162dd79ce932668b43d5cd7aac945b8e3a59` mit ZIP-SHA-256
> `E78465CDE0009CBBB18DE9F2DC12083981DD2472141ABC87A3A3F267599B376D`
> blieb auf realer Hardware bei 30 % stehen. Dieser E784-Kandidat sowie das
> danach intern als 979-Paket bezeichnete Archiv sind zurückgezogen und dürfen
> nicht auf einen Fahrzeug-USB-Stick gelangen. Maßgeblich ist ausschließlich
> der unten vollständig festgeschriebene Release aus Commit
> `325d91084fe32e95b60672bff3e3b0f252e91a4f`.

Ford SYNC ist ausschließlich ein Anzeige- und Bedienclient. Zustand, Cache,
DWD-/BSH-Wetter, Gezeitenkurve, Persistenz, Schutzlogik und die abschließende
Validierung aller Befehle gehören dem Cerbo-Backend. Die App ruft keine
Wetterquelle direkt auf und berechnet keine eigenen Ersatzwerte.

## Festgeschriebener Release

| Merkmal | Wert |
|---|---:|
| Quellcommit | `325d91084fe32e95b60672bff3e3b0f252e91a4f` |
| App-Version | `3.12.0` |
| ZIP | `dist/CamperControl-SYNC3-v3.12.0.zip` |
| ZIP-Größe | `658932` Bytes |
| ZIP-Einträge | `40` |
| ZIP-SHA-256 | `4F6C20CD52CDE241D784F14B4A263CD4315F034E4023D1C10A6EC86DD848FDB9` |
| Manifestierte Nutzdateien | `39` |
| USB-Stage | `dist/CamperControl-SYNC3-v3.12.0-USB` |
| USB-Stage-Dateien | `40` |
| Entpackte Nutzbytes | `859733` Bytes |
| Content-Hash des USB-Stages | `394a411c56a703f9de7e88743c7862a14d78e6173794b00f257c607568e2d732` |
| ZIP ↔ USB-Stage | `40/40` Dateien bytegleich |

Der ZIP-Hash ist der maßgebliche Download-/USB-Pin. Das interne
`SyncMyMod/files/release-manifest.cksum` deckt jeden der übrigen 39 Einträge
genau einmal mit POSIX/QNX-`cksum`, Pfad und Größe ab. Der Installer prüft
dieses Manifest vollständig, bevor er Ford-Dateien verändert.

## Voraussetzungen

### Buildrechner

- Git;
- Python 3;
- PyQt5 mit QtQuick/QtTest für die echten Qt-5-/800×480-Tests;
- Pillow für die PNG-/Transparenzverträge;
- PowerShell 7;
- ein POSIX-`sh` auf `PATH`, zum Beispiel aus Git Bash oder WSL, damit der
  atomare Installer-Fixturetest tatsächlich ausgeführt und nicht ausgelassen
  wird.

WSL ist für den ZIP-Build nicht erforderlich. Alle Befehle werden im
Repository-Stamm `sync3-camper` ausgeführt.

### Ford SYNC

- gejailbreaktes Ford SYNC 3.4;
- FMods Tools 3.3 oder neuer;
- Custom Apps Loader 2.3;
- SYNC und Cerbo in einem gegenseitig erreichbaren WLAN;
- der zuvor abgenommene CamperControl-v2-Backendstand auf dem Cerbo.

Es wird kein Passwort, WLAN-Schlüssel oder Token in das ZIP geschrieben. Eine
optionale Cerbo-Adresse wird erst im Fahrzeug unter `SETTINGS` gespeichert.

## Quellstand prüfen

PowerShell:

```powershell
$sourceCommit = '325d91084fe32e95b60672bff3e3b0f252e91a4f'
git cat-file -e "$sourceCommit`^{commit}"
if ($LASTEXITCODE -ne 0) { throw "SYNC-Quellcommit fehlt: $sourceCommit" }
git merge-base --is-ancestor $sourceCommit HEAD
if ($LASTEXITCODE -ne 0) {
    throw "HEAD enthält den freigegebenen SYNC-Quellcommit nicht"
}
$sourceChanges = @(git diff --name-only $sourceCommit -- . ':(exclude)BUILD_DEPLOY.md')
if ($sourceChanges.Count -ne 0) {
    throw "Quellinhalt weicht vom Releasecommit ab: $($sourceChanges -join ', ')"
}
$trackedChanges = @(git status --porcelain --untracked-files=no)
if ($trackedChanges.Count -ne 0) {
    throw "Versionierte Dateien sind geändert: $($trackedChanges -join ', ')"
}
if (-not (Get-Command sh -ErrorAction SilentlyContinue)) {
    throw 'POSIX-sh für den Installer-Fixturetest fehlt'
}
```

Ein Release wird bevorzugt in einem separaten, abgetrennten Worktree dieses
Commits gebaut. Unversionierte Vorschauen und Referenzbilder gelangen dadurch
nicht versehentlich in den USB-Stage.

## Tests

Die vollständige Release-Suite lautet:

```powershell
python -m unittest discover -s tests -p "test_*.py"
python tools/check_qml.py --without-sync
python tools/check_design_persistence.py
python tools/check_v2_runtime.py
```

Die Suite prüft unter anderem:

- den V2-only-Dateivertrag und die feste Positivliste;
- zwei bytegleiche, reproduzierbare Test-ZIPs;
- vollständige POSIX-`cksum`-Abdeckung aller ZIP-Einträge;
- begrenzten `/fs/rwdata`-Verbrauch und atomaren App-Verzeichnistausch;
- automatische Wiederherstellung nach einem fehlgeschlagenen App-Swap;
- API-URL, Command-Queue, WLAN-Fallback und Cerbo-Ownership;
- Favoriten, Wetter, Tidekurve, Energie, Klima, Licht und Touchgeometrie;
- echte QtQuick-2.6-Ladbarkeit und die 800×480-Tag-/Nacht-/Touch-Laufzeit.

Fehlendes PyQt5, Pillow oder `sh` ist für einen Release kein bestandener oder
überspringbarer Test, sondern ein zu behebender Umgebungsfehler.

## Reproduzierbares ZIP bauen

Der kanonische Build:

```powershell
python tools/build_release.py
```

Der Builder verwendet eine feste V2-Positivliste, Deflate-Stufe 9, feste
Dateimodi und für alle Einträge den festen ZIP-Zeitstempel
`2026-08-20 00:00:00`. Er schreibt genau:

```text
dist/CamperControl-SYNC3-v3.12.0.zip
```

Zur unabhängigen Reproduzierbarkeitsprüfung wird ein zweites Archiv erzeugt:

```powershell
python tools/build_release.py `
  --output .\dist\CamperControl-SYNC3-v3.12.0-repeat.zip

$first = '.\dist\CamperControl-SYNC3-v3.12.0.zip'
$second = '.\dist\CamperControl-SYNC3-v3.12.0-repeat.zip'
$firstHash = (Get-FileHash -LiteralPath $first -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $second -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'SYNC-Build ist nicht reproduzierbar' }
if ($firstHash -ne '4F6C20CD52CDE241D784F14B4A263CD4315F034E4023D1C10A6EC86DD848FDB9') {
    throw "Unerwarteter SYNC-ZIP-Hash: $firstHash"
}
$zipBytes = (Get-Item -LiteralPath $first).Length
if ($zipBytes -ne 658932) {
    throw 'Unerwartete SYNC-ZIP-Größe'
}
```

Einträge und entpackte Nutzbytes prüfen:

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $first))
try {
    if ($archive.Entries.Count -ne 40) { throw 'ZIP muss 40 Einträge enthalten' }
    $bytes = ($archive.Entries | Measure-Object Length -Sum).Sum
    if ($bytes -ne 859733) { throw "Unerwartete Nutzbytes: $bytes" }
    $names = @($archive.Entries.FullName)
    foreach ($required in @(
        'DONTINDX.MSA',
        'SyncMyMod/autoinstall.sh',
        'SyncMyMod/files/release-manifest.cksum'
    )) {
        if ($required -notin $names) { throw "ZIP-Eintrag fehlt: $required" }
    }
} finally {
    $archive.Dispose()
}
```

Das finale ZIP und sein Hash werden unverändert in das Gesamtrelease
übernommen. Ein nachträgliches Umpacken ist nicht zulässig.

Der Content-Hash des entpackten Stages wird ordinal aus
`relativer/pfad|größe|sha256lower` mit UTF-8 ohne BOM und genau einem LF nach
jeder Zeile gebildet:

```powershell
$stageTarget = 'dist\CamperControl-SYNC3-v3.12.0-USB'
if (Test-Path -LiteralPath $stageTarget) {
    throw 'Lokaler USB-Prüfstage muss vor dem Entpacken fehlen'
}
Expand-Archive -LiteralPath $first -DestinationPath $stageTarget
$stage = (Resolve-Path $stageTarget).Path
$lines = Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
    $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    '{0}|{1}|{2}' -f $relative, $_.Length, $sha
} | Sort-Object
$bytes = [Text.Encoding]::UTF8.GetBytes((($lines -join "`n") + "`n"))
$contentHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bytes)
).ToLowerInvariant()
if ($contentHash -ne '394a411c56a703f9de7e88743c7862a14d78e6173794b00f257c607568e2d732') {
    throw "Unerwarteter USB-Stage-Hash: $contentHash"
}
```

Zusätzlich werden die 40 Archivdateien einzeln mit dem entpackten Stage
verglichen:

```powershell
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $first))
$matched = 0
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $target = Join-Path $stage $entry.FullName.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw "Stage-Datei fehlt: $($entry.FullName)"
        }
        $stream = $entry.Open()
        try {
            $zipSha = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($stream)
            )
        } finally {
            $stream.Dispose()
        }
        $stageSha = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($entry.Length -ne (Get-Item -LiteralPath $target).Length -or $zipSha -ne $stageSha) {
            throw "ZIP und Stage unterscheiden sich: $($entry.FullName)"
        }
        $matched++
    }
} finally {
    $archive.Dispose()
}
if ($matched -ne 40) { throw "Erwartet waren 40/40 bytegleiche Dateien, gefunden: $matched" }
```

## USB-Stick sicher vorbereiten

Einen leeren Stick verwenden. Der Laufwerksbuchstabe muss vor dem Entpacken
bewusst geprüft werden; im folgenden Beispiel ist es `E:`:

```powershell
$usbRoot = 'E:\'
if (-not (Test-Path -LiteralPath $usbRoot)) { throw 'USB-Laufwerk fehlt' }
$existing = @(Get-ChildItem -LiteralPath $usbRoot -Force)
if ($existing.Count -ne 0) { throw 'USB-Stick ist nicht leer' }

Expand-Archive `
  -LiteralPath .\dist\CamperControl-SYNC3-v3.12.0.zip `
  -DestinationPath $usbRoot

$usbFiles = @(Get-ChildItem -LiteralPath $usbRoot -File -Recurse)
if ($usbFiles.Count -ne 40) { throw "USB muss 40 Dateien enthalten: $($usbFiles.Count)" }
$usbBytes = ($usbFiles | Measure-Object Length -Sum).Sum
if ($usbBytes -ne 859733) { throw "Unerwartete USB-Nutzbytes: $usbBytes" }
if (-not (Test-Path -LiteralPath (Join-Path $usbRoot 'DONTINDX.MSA'))) {
    throw 'DONTINDX.MSA fehlt im USB-Stamm'
}
if (-not (Test-Path -LiteralPath (Join-Path $usbRoot 'SyncMyMod\autoinstall.sh'))) {
    throw 'SyncMyMod/autoinstall.sh fehlt'
}
```

Direkt im USB-Stamm dürfen nur `DONTINDX.MSA` und der Ordner `SyncMyMod`
liegen. Ein früher verwendeter Stick darf nicht einfach überkopiert werden,
weil sonst alte, nicht zum Manifest gehörende Dateien erhalten bleiben können.

## Installationsreihenfolge

SYNC wird erst installiert, wenn die zentrale Kette abgenommen ist:

1. Cerbo-D-Bus-/Wetterdienst;
2. Node-RED-Flow und lokale HTTP-v2-API;
3. native GX-Oberfläche;
4. WASM/Remote Console;
5. Ford-SYNC-USB-Paket.

Damit trifft die SYNC-App beim ersten Start bereits auf den vollständigen
zentralen Vertrag.

## Installation oder Upgrade im Fahrzeug

1. Zündung und Bordspannung stabil halten und SYNC vollständig starten lassen.
2. Den geprüften USB-Stick einsetzen.
3. Der Installer prüft FMods Tools, Custom Apps Loader, jede manifestierte
   USB-Datei, `apps.json`, Ford-`Root.qml`, Statusleiste, vorhandene
   Camper-Integration und ausschließlich die erwarteten Backup-/Stage-Pfade,
   bevor `/fs/mp` schreibbar wird. Er führt während der Installation bewusst
   weder rekursive Dateisystemläufe noch einen potenziell blockierenden
   Speicher-Probe aus.
4. Ein unbekannter oder nur teilweise bekannter Ford-QML-Stand führt ohne
   Änderung zum Abbruch.
5. Der Kandidat wird als `Camper.camper-new` auf demselben Dateisystem
   vorbereitet. Die aktive App wird nur per Rename zu `Camper.camper-old` und
   der Kandidat anschließend atomar aktiviert.
6. Erst bei „App and Ford integration installed. Remove USB to reboot.“ den
   Stick entfernen.
7. Nach dem Neustart `Apps → Custom Apps → Camper` öffnen.
8. Unter `SETTINGS` bei Bedarf nur die Cerbo-Adresse eintragen. Die lokale
   Konfiguration liegt unter `/fs/rwdata/fmods/mods/camper/config.json`.

Bei einem Fehler innerhalb der Transaktion stellt der Installer `apps.json`,
App-Verzeichnis, Root, Statusleiste, Bridge und Mod-Marker automatisch auf den
unmittelbar vorherigen Stand zurück.

## Begrenzter Speicher und alte Versionen

Nach erfolgreicher Installation existiert genau ein aktives App-Verzeichnis:

```text
/fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper
```

Bei Schritt `30/2` validiert der Installer zuerst genau ein kanonisches,
Camper-freies Ford-Originalpaar unter
`/fs/rwdata/fmods/mods/camper-complete/original/`. Bei einem Upgrade werden
zuerst die bekannten `camper-complete/*.transaction`-Dateien und danach das
bekannte `camper-statusbar/*.before`-Paar geprüft; bei einer sauberen
Erstinstallation kann das unveränderte aktive Ford-Paar als Quelle dienen. Ein
leeres, beschädigtes oder bereits von Camper verändertes Paar wird abgelehnt.

Erst danach entfernt Schritt `30/3` bekannte Altstände ausschließlich über
feste Positivlisten:

```text
.../Camper.camper-new
.../Camper.camper-old
/fs/rwdata/fmods/mods/camper/app.previous
/fs/rwdata/fmods/mods/camper/apps.json.before
/fs/rwdata/fmods/mods/camper-complete/transaction
/fs/rwdata/fmods/mods/camper-complete/app.transaction
/fs/rwdata/fmods/mods/camper-complete/apps.json.transaction
/fs/rwdata/fmods/mods/camper-complete/Root.qml.transaction
/fs/rwdata/fmods/mods/camper-complete/StatusBarDriverTemperature.qml.transaction
/fs/rwdata/fmods/mods/camper-statusbar/Root.qml.before
/fs/rwdata/fmods/mods/camper-statusbar/StatusBarDriverTemperature.qml.before
/fs/rwdata/fmods/mods/camper-statusbar/restore-statusbar-root.sh
```

Die alten `*.transaction`-Pfade werden erst gelöscht, nachdem das dauerhafte
Originalpaar validiert wurde. Enthält ein alter Pfad ein unbekanntes
Unterverzeichnis, FIFO oder eine nicht positiv gelistete Datei, bricht die
Bereinigung fail-closed ab, statt rekursiv in unbekannte Daten zu laufen. Der
Installer verwendet dabei weder `find` noch `df` und entfernt keine fremden
Mods. Insbesondere bleibt `/fs/rwdata/fmods/mods/camper/config.json`
unverändert.
Dauerhaft bleiben bewusst nur:

- die ursprünglichen Ford-Dateien unter
  `/fs/rwdata/fmods/mods/camper-complete/original/`;
- das Restore-Skript
  `/fs/rwdata/fmods/mods/camper-complete/restore-statusbar-root.sh`;
- das kleine, bei jedem Lauf überschriebene `install-last.log`;
- die aktuelle Benutzereinstellung unter `mods/camper/config.json`.

Es werden also keine vollständigen alten Camper-App-Versionen auf
`/fs/rwdata` gesammelt.

## Verifikation im Fahrzeug

Zuerst den letzten Installerstatus im FMods-Shell lesen:

```sh
cat /fs/rwdata/fmods/mods/camper-complete/install-last.log
test -d /fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper
test ! -e /fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper.camper-new
test ! -e /fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper.camper-old
test ! -e /fs/rwdata/fmods/mods/camper-complete/transaction
```

`install-last.log` muss `state=success`, `step=complete` und `reason=none`
enthalten. Anschließend direkt am 800×480-Display prüfen:

- Tag und Nacht füllen alle vier Ecken ohne schwarzen Reststreifen;
- Transit-/FORD-Symbol, obere Schließen-Taste und Ford-Systemseite arbeiten;
- Rückfahrkamera, Frontkamera und Parkpilot behalten Priorität;
- Home, Licht, Klima, 12/230 V, Wasser und System sind erreichbar;
- Favoriten links und DWD-/BSH-Wetter rechts öffnen ohne sichtbaren Griff;
- Wetter und Tidekurve stammen aus dem Cerbo-Snapshot und zeigen bei
  fehlenden Daten keine erfundenen Werte;
- Licht-Hotspots, Schalter und Dimmer bestätigen den realen Cerbo-Zustand;
- direkte Cerbo-Verbindung und Fahrzeug-LAN werden wiedergefunden;
- lokale Starlink-Bedienung bleibt möglich; Remote-Schutz bleibt Cerbo-Aufgabe.

## Deinstallation und vollständiger Restore

Das lange Drücken der Camper-Kachel deinstalliert die App und entfernt die
lokale Konfiguration sowie den App-Marker. Es stellt allein jedoch nicht die
globalen Ford-Dateien wieder her.

Für einen vollständigen Rückbau wird im FMods-Shell das mit der Installation
abgelegte, fest adressierte Restore-Skript ausgeführt:

```sh
sh /fs/rwdata/fmods/mods/camper-complete/restore-statusbar-root.sh
```

Das Skript verweigert den Lauf, wenn das Originalpaar fehlt oder selbst
Camper-Marker enthält. Bei Erfolg stellt es ausschließlich die beiden
gesicherten Ford-Dateien wieder her, entfernt die Camper-Bridge und den
Statusbar-/Root-Mod-Marker und hängt `/fs/mp` wieder read-only ein. Danach die
Camper-App über den Custom Apps Loader deinstallieren und SYNC neu starten.

Die Originaldateien werden bei Upgrades nie überschrieben. Sie dürfen nicht
manuell gelöscht werden. Ein unbekannter Ford-QML-Stand, eine Teilkopie oder
ein fehlendes Originalpaar ist ein Abbruchgrund; in diesem Fall keine weiteren
Installationsversuche starten, bevor die konkrete Sicherung geprüft wurde.
