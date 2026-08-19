# Statusleisten-Integration – noch nicht installieren

Diese Dateien sind ein Integrationsgerüst und werden durch `autoinstall.sh` bewusst nicht auf das APIM kopiert oder gepatcht.

Für einen sicheren gemeinsamen Kamera-/Camper-Patch werden zuerst benötigt:

- die aktuell aktive und gegebenenfalls bereits vom RVC-Mod veränderte `StatusBarDriverTemperature.qml`,
- die tatsächlich aktive bildschirmfüllende `Root.qml` einschließlich Theme-/Variantenpfad,
- `/fs/mp/etc/installed_mods.txt`,
- vorhandene `.orig`-/`.ori`-Sicherungen.

Danach werden `CamperState.qml` und `qmldir` nach `/fs/mp/fordhmi/qml/hmicustomapps/camperbridge/` kopiert. Der Statusleisten-Code kommt gemeinsam mit `rvcShortcutItem` in denselben geprüften Patch. Der Root-Loader wird gegen die gelieferte Root-Datei mit `patch --dry-run` validiert.

Bis dahin startet die App sicher über **Apps → Custom Apps → Camper**. In diesem Modus übernimmt die vorhandene SYNC-Zurück-Funktion des Custom Apps Loaders das Schließen.
