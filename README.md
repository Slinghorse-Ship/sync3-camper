# CamperControl 3.9.9 für SYNC 3.4 / FMods

Reine QtQuick-2.6-App für den **Custom Apps Loader 2.3**. Sie benötigt keine native QNX-Binärdatei, keine Qt-WebSocket-Erweiterung und kein separates Desktop-QML-Projekt.

## Voraussetzungen

- gejailbreaktes SYNC 3.4,
- FMods Tools 3.3 oder neuer,
- Custom Apps Loader 2.3,
- CamperControl-Node-RED-v4-Flow auf dem Cerbo GX,
- SYNC und Cerbo im selben erreichbaren WLAN.

## Installation

Den Inhalt des ZIPs in das Stammverzeichnis eines leeren USB-Sticks entpacken. Dort müssen `SyncMyMod` und `DONTINDX.MSA` liegen. Dieser eine Installer installiert die QML-App, registriert `com.jan.camper` in Version 3.9.9 und integriert gleichzeitig Transit-Symbol, globalen Root-Loader sowie den Kamera- und Parkpilot-Vorrang in die Ford-Statusleiste. Bei einem Upgrade wird der geprüfte Kamera-Sichtbarkeitsblock ohne Aufruf des Patch-Programms atomar ersetzt. Vor jeder Änderung werden App, `apps.json`, `Root.qml` und Statusleiste geprüft und gesichert. Bei einem unbekannten Ford-QML-Stand wird nichts verändert.

Version 3.9.3 ergänzt für alle dimmbaren Lichtkacheln eine getrennte Bedienung: Die Kachel schaltet direkt An/Aus, der schmale Dimm-Balken öffnet einen großen horizontalen Regler mit Voreinstellungen. Die Orion-XS-Umwandlungsanzeige, Einstellungen sowie Kamera- und Parkpilot-Vorrang bleiben vollständig enthalten.

Version 3.9.4 ergänzt auf der Energie-/INDEVOLT-Seite die lokale Freigabe der 230-V-Stromzufuhr zum Campernetz über einen vom Cerbo nativ eingebundenen Shelly 1PM Gen4. Der Schalter und seine Messwerte erscheinen nur, wenn der D-Bus-Dienst tatsächlich verfügbar ist.

Version 3.9.9 ergänzt die aktuelle Cerbo-Ethernet-Adresse als unsichtbaren API-Fallback. Damit findet die App Node-RED sowohl direkt über den Cerbo-Access-Point als auch aus dem gemeinsamen Fahrzeug-/Starlink-LAN. Version 3.9.8 entfernte den alten RVC-Statusleisten-Knopf einschließlich Icon, Touch-/Drag-Logik und Statusleisten-Kamerabefehl vollständig; Rückfahrkamera, Frontkamera und Parkpilot in `Root.qml` bleiben unverändert. Das 46-Pixel-Transit-Symbol übernimmt dessen gespeicherte frühere Position mit einer eigenen 60 × 54 Pixel großen Touchfläche. Der App-Wechsel erfolgt nach einem abgeschlossenen Klick über einen kurzen Timer. Das Upgrade erfolgt über einen begrenzten atomaren Dateitausch mit automatischem Rollback und verwendet keinen interaktiven Patch-Aufruf.

Version 3.7.9 nimmt den gesamten sichtbaren Camper-Bildschirm als eigene Touchfläche an. Berührungen auf freien Flächen oder zwischen Bedienelementen können dadurch nicht mehr zusätzlich Radio-, Klima- oder Navigationsknöpfe der darunterliegenden Ford-Oberfläche auslösen. Während Kamera und Parkpilot die Camper-App ausblenden, ist diese Touch-Abschirmung ebenfalls vollständig inaktiv.

Version 3.7.8 entlastet die alte SYNC-Hardware durch einen ruhigen, dauerhaft laufenden Hintergrundabruf. Unmittelbar nach Schaltbefehlen werden mehrere kurze Bestätigungsabfragen ausgeführt, sodass Licht und 12-V-Ausgänge weiterhin schnell reagieren, ohne dass sich HTTP-Verbindungen und große Zustandsantworten aufstauen.

Version 3.7 bildet die tatsächliche STAR-Power-Verkabelung ab. Ausgang 3 schaltet den Zusatz-Fernlichtbalken; Cerbo-Digitaleingang 4 liefert zusätzlich dessen Fahrzeug-Fernlichtzustand. Die serienmäßigen Ford-Scheinwerfer werden weder geschaltet noch beleuchtet dargestellt. Kanal 7 ist der weiße Tagfahrlicht-Streifen im Balken, Kanal 8 der orange Warnlicht-Streifen; dessen Blinkrhythmus erzeugt Node-RED ausschließlich per Ein/Aus. Die Lichtseite verwendet große Schaltflächen und direkt bedienbare Helligkeitsregler. Die Fahrerseite wird ohne Markise im Vordergrund gezeigt; auf der Beifahrerseite liegt die Markise sichtbar im Vordergrund. Autotherm und MaxxFan werden über ihre Gerätebeschriftung geöffnet. Die Temperaturseite zeigt alle verfügbaren Messwerte. Ihre unabhängige Raumklima-Automatik kann je nach Innenraumtemperatur AUTOTERM oder MaxxFan anfordern. Separat schützt die CPU-Lüftung den Cerbo anhand seiner eigenen SoC-/CPU-Temperatur und schaltet dafür Relais 1 (Abluft) und Relais 2 (Zuluft). Zusätzlich kann der gemeinsame Lüfterlauf in SYNC manuell ein- und ausgeschaltet werden. Die Solar-/INDEVOLT-Kachel öffnet alle Victron-MPPTs und INDEVOLT-Geräte. Unten stehen nur HOME, LICHT und 12/230; Meldungen und Service liegen in den Einstellungen. Befehlsdetails bleiben im Ereignis- und Diagnoseprotokoll verfügbar, ohne die Bedienung zu verdecken. Die SmartShunt-Kachel zeigt Hauptbatterie, Messung 2/Starterbatterie, Strom, Leistung, Verbrauch, Restzeit und Kapazität.

Unter `SETTINGS` können Innenlicht sowie die fünf Außenleuchten frei und ohne Doppelbelegung den dimmbaren STAR-Power-Kanälen 7–12 zugeordnet werden. Die Zuordnung wird dauerhaft im Cerbo gespeichert.

Nach dem Neustart: **Apps → Custom Apps → Camper**. Über `SETTINGS` kann bei Bedarf die Cerbo-Adresse eingetragen werden. Ein Token wird nicht benötigt. Eine reine IP genügt; die App ergänzt `http://`, Port `1880` und `/camper/api/v2` automatisch:

- Cerbo-Access-Point: `172.24.24.1`
- Starlink/anderes WLAN: beispielsweise `192.168.1.42`

Die Konfiguration liegt unter `/fs/rwdata/fmods/mods/camper/config.json`.

## Funktionen

- SmartShunt, Victron-Solar, INDEVOLT, Wasser, AUTOTERM, MaxxFan und MultiPlus Compact
- AUTOTERM Start/Stopp, Temperatur-, Leistungs- und Lüftungsmodus sowie die im seriellen Bestand vorhandenen Schutz- und Wartungseinstellungen
- eigene Seite für sechs STAR-Power-Lichtkreise; fünf davon dimmbar, Warnlicht als reines Blinksignal
- eigene Seite „12/230 V“ für MultiPlus, 12 V links/rechts, Wasserpumpe, manuelles Fernlicht, Starlink und MaxxFan-Versorgung
- frei konfigurierbare Szenen
- physisch bestätigte Befehle im Diagnoseprotokoll, ohne störende Einblendung über der Bedienoberfläche
- Alarm- und Ereigniscenter mit Quittierung
- Geräteverbindungen, Abbrüche und Antwortzeiten
- Verlauf, Batterie-/Wasserprognose und Wartungsplan
- keine zündungs-, geschwindigkeits- oder gangabhängigen Bediengrenzen

Die App wählt die erreichbare Cerbo-Verbindung automatisch aus der gespeicherten Adresse, dem Victron-AP, `venus.local`, `einstein` und `einstein.local`. Die konkrete Netzart bleibt unsichtbar; angezeigt werden nur `Verbunden` oder `Keine Verbindung`.

Die App fragt den gemeinsamen Zustand alle 500 ms über die einzige aktuelle HTTP-v2-Schnittstelle ab. Alte HTTP-v1- und ungenutzte WebSocket-Endpunkte sind nicht mehr enthalten. Schutzfunktionen des Geräts bleiben erhalten: insbesondere AUTOTERM-Nachlauf/Unterspannung und die hardwareseitige STAR-Power-Absicherung.

## Statusleisten-/Root-Integration

Sie ist Bestandteil desselben `SyncMyMod`-Installers. Unterstützt werden die geprüfte originale Ford-Datei, die ältere Camper-Integration und der bereits aktuelle Stand. Bei Rückfahr- oder Frontkamera bleibt die App geladen, wird aber für die gesamte Vollbild-Kameraansicht unsichtbar und erscheint danach auf derselben Seite wieder.

## Entfernen

Im Custom Apps Loader die Camper-Kachel lange drücken und die Löschung bestätigen. Dessen `app_delete.sh` ruft das mitgelieferte `uninstall.sh` auf und entfernt anschließend App-Eintrag und App-Ordner.
