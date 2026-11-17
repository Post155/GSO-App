# GSO Campus Navigator 2.0

Konfigurierbare Web-App für das Georg-Simon-Ohm-Berufskolleg Köln: Dashboard, Campuskarte, EG/OG, Tür-/Flurrouting, alternative Wege und Kartenwerkstatt. Keine npm-Laufzeitabhängigkeiten, kein Build-Framework und kein eigener Backenddienst erforderlich.

## Starten

1. Node.js 20 oder neuer installieren.
2. ZIP entpacken. Unter Windows `START-WINDOWS.bat` öffnen; alternativ `npm start` im Projektverzeichnis ausführen.
3. `http://localhost:4173` aufrufen. Zum Beenden Strg+C drücken.

`index.html` nicht direkt als lokale Datei öffnen: Die Karte lädt JSON-Dateien per HTTP. Die veröffentlichte Website läuft unter https://gso-campus-navigator.cgi.chatgpt.site.

## Prüfen und veröffentlichen

```sh
npm test
npm run build
npm start
```

Kein `npm install` notwendig. `npm run build` prüft die Dateien und erzeugt eine versionierte Offline-Dateiliste. Für Hosting den Inhalt von `dist/` bereitstellen. Die vorhandene Sites-Identität steht unter `.openai/hosting.json` und wird beibehalten. Zugangsdaten sind nicht enthalten.

## Räume und Karte ändern

- Zentraler Raumkatalog: `dist/config/rooms.json`.
- Bearbeitbare Ziele, Wegpunkte, Verbindungen, Flächen und Straßen: `dist/config/campus.json`.
- In der App: Karte → Entwicklermodus. JSON-Import/-Export, Raumkatalog-Import/-Export, lokale Speicherung, Rückgängig/Wiederholen.
- Neue Räume erhalten eine eindeutige ID mit `dev-` am Anfang. Ein neuer Raum benötigt einen Anschluss an einen vorhandenen oder neu gezeichneten Wegpunkt.
- Browseränderungen gelten nur für dieses Gerät. Für einen gemeinsamen Stand JSON-Datei exportieren und in den veröffentlichten Kartenstand übernehmen.

Einzelheiten: [Konfiguration](docs/KONFIGURATION.md), [Architektur](docs/ARCHITEKTUR.md), [Abschlussbericht](docs/ABSCHLUSSBERICHT.md).

## Nachgewiesener Datenstand und Grenzen

154 Raumziele, davon 141 mit Wegpunkt; 764 Graphknoten und 883 Verbindungen. 270 von 292 erkannten Türpunkten sind am Netz angeschlossen. 22 Türanschlüsse, die Sporthalle und ein durchgängiger Aufzugübergang sind noch nicht vollständig geklärt. Solche Verbindungen werden nicht erfunden. Neue/manuell verschobene Innenwege werden gegen das aus den PDF-Wänden abgeleitete Raster geprüft.

Die Karte ist schematisch. Keine automatische Indoor-Ortung und keine geprüfte Fluchtwegplanung. Standort manuell über „Ich bin hier“ oder einen Standort-Link setzen. Die Offline-Karte wird nach erfolgreichem erstmaligem Online-Laden vorbereitet; Offline-Verhalten im echten Browser ist noch separat zu prüfen.

## Verzeichnisstruktur

```text
 dist/                 Auslieferbare Web-App
   config/             Räume, Graph, Gebäude, Wandmaske, Migrationen
   js/core/            Zustand und Datenprüfung
   js/navigation/      Unabhängiger Routing-Kern und Kartenadapter
   js/map/             Darstellung und Gesten
   js/editor/          Bearbeitung, Bindungen, Speicherung
   js/ui/              Dashboard, Suche, Raumkarten, Katalogverwaltung
   assets/             Baupläne, Vorlagen, Vektorgeometrie und Herkunftsdaten
 tests/                Automatisierte Prüfungen
 scripts/              Start, Offline-Build und Benchmark
 tools/source-generation/ Optionale PDF-/Bildgewinnung mit Python
 docs/                 Bericht und technische Anleitung
```
