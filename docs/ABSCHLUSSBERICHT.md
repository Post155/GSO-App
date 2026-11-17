# Software-Analyse und Optimierung – GSO Campus Navigator 2.0

**Stand:** 17. November 2026 · **Projekt:** Georg-Simon-Ohm-Berufskolleg Köln · **Auslieferung:** Quellcode, statische Web-App, Konfiguration, Prüfungen und Dokumentation im ZIP; gleiche Anwendung auf der bestehenden Website.

## Ergebnis und tatsächlicher Fertigstellungsgrad

Die Anwendung wurde fachlich neu gegliedert, der aktive historische Überschreibungsstapel entfernt und das Dashboard ergänzt. Der Routing-Kern unterstützt innerhalb und zwischen EG/OG dynamische kürzeste Wege, einen tatsächlich anderen Alternativweg sowie Treppen-/Aufzugregeln. Innenkanten werden auch nach manueller Bearbeitung gegen die Wandmaske geprüft. Die manuell eingezeichneten Außenknoten und deren bestehenden Verbindungen bleiben erhalten.

| Datenstand | Nachgewiesener Wert |
|---|---:|
| Sichtbare Ziele einschließlich Außenbereich | 172 |
| Raumziele in EG und OG | 154 |
| Raumziele mit hinterlegtem Wegpunkt | 141 |
| Graphknoten / ungerichtete Verbindungen | 764 / 883 |
| Erkannte Türpunkte | 292 |
| Angeschlossene und vom Eingangsnetz erreichbare Türpunkte | 270 |
| Noch offene Türpunkte | 22 |
| Angebundene Gebäudeeingänge | 8 von 9 |
| Treppenübergänge zwischen EG und OG | 4 |
| Durchgängig bestätigte Aufzugverbindungen | 0 |

**Die Routing-Software ist umgesetzt, die zugrunde liegende Erfassung noch nicht vollständig.** 22 Türanschlüsse, 13 Raumziele ohne Wegpunkt und der Sporthallen-Eingang bleiben offen. Unbekannte Türen, Kantine oder Notausgänge werden nicht anhand von Vermutungen erfunden. Stufenfreie Etagenrouten bleiben ohne bestätigten Aufzug gesperrt. Eine vollständige örtliche Freigabe aller Räume kann aus den vorhandenen Zeichnungen allein nicht seriös zugesagt werden.

## Umfang und Vorgehen

Untersucht wurden alle ursprünglich aktiven JavaScript-/CSS-/HTML-Dateien, Editor- und Migrationspfade, Service Worker, Manifest, Karten-/Graphkonfiguration, Generatoren, vorhandene Prüfskripte und Dokumentation. Die veralteten Prüfungen bezogen sich teilweise auf frühere leere Arbeitsflächen statt auf den tatsächlich veröffentlichten Stand; sie wurden durch eine gemeinsame aktuelle Suite ersetzt. Die optionalen Python-Generatoren wurden syntaktisch geprüft und aus dem Laufzeitpfad getrennt; ihre vollständige Neugenerierung wurde bewusst nicht ausgeführt, weil sie freigegebene Karten-Zwischenstände ersetzen würde.

Dies ist eine nachvollziehbare Quellcode- und Funktionsprüfung, keine formale Sicherheitszertifizierung und keine Garantie für die Abwesenheit aller Fehler. Ein vollständiger interaktiver Browsertest war mangels vorgesehener Browserumgebung nicht möglich. Tastatur-, Touch-, Kiosk- und echte Offline-Interaktionen benötigen deshalb zusätzlich einen Abnahmelauf auf den Zielgeräten.

## Befunde, Auswirkungen und direkt umgesetzte Änderungen

| ID / Bereich | Problem und Auswirkung | Konkrete Verbesserung und Umsetzung |
|---|---|---|
| Q01 Architektur | Entwicklungsstände überschrieben globale Funktionen mehrfach; Aufrufreihenfolge und Fehlerursachen waren schwer nachvollziehbar. | Aktive alte Einstiegsskripte entfernt; 17 fachliche Dateien in `core`, `navigation`, `map`, `editor`, `ui`. Explizite benannte Hilfsoperationen statt Laufzeitüberschreibung. |
| Q02 Initialisierung | Mehrere Editor-Initialisierer erzeugten Zwischenstände, restaurierten Daten wiederholt und banden dieselben Eigenschaften mehrfach. | Eine Initialisierung und eine Bindungsroutine; fünf doppelte Kontrollbindungen entfernt. |
| Q03 Toter Code | Frühere leere Arbeitsfläche, historische Umgebungsgeneratoren und überholte Prüfskripte lagen im aktiven Einstieg. | Historische Frontends und obsolete Tests entfernt; Herkunftswerkzeuge separat nach `tools/source-generation/` verschoben. |
| Q04 Lesbarkeit | Stark zusammengedrückte Funktionen, kaum fachliche Grenzen und teilweise veraltete README-Angaben. | Quellcode strukturiert, Kontrollblöcke geklammert, zentrale Funktionen kommentiert; aktuelle Architektur-/Konfigurationsanleitung und dieser Bericht. |
| Q05 Doppelte Logik | Snapshot, Wiederherstellung und Prüfung wurden über mehrere Varianten verteilt. | Ein Format in `editor/persistence.js`, ein zentraler Prüfer in `core/configuration.js`; gemeinsame Geometrie im Python-Hilfsmodul. |
| Q06 Routing-Performance | Die nächste Dijkstra-Position wurde bei jedem Schritt linear aus einer Menge ermittelt. | Min-Heap mit Überspringen veralteter Einträge; Routing unabhängig von DOM und UI testbar. |
| Q07 Wanddurchquerung | Manuell verschobene Innenwege wurden nur gegen zusätzliche Sperrpolygone geprüft. | PDF-basierte bitgepackte Wandmaske, inverse Registrierung, dichte Segmentprüfung und Diagonalschutz auch für bearbeitete Kanten. |
| Q08 Zahlenpräzision | Rückumrechnung gerundeter Weltkoordinaten und unterschiedliches Halbzellenrunden konnten gültige Türkanten fälschlich blockieren. | Einheitliche deterministische Halbzellenrundung und begrenzte numerische Rückführungs-Toleranz; alle 270 angeschlossenen Türen erneut erreichbar geprüft. |
| Q09 Übergangsregeln | Der Routing-Kern selbst verließ sich stark auf vorausgehende Datenprüfung. | Unbestätigte Etagen-/Gebäudeübergänge werden zusätzlich im Kern gesperrt. Treppen stufenfrei aus-, Aufzüge im Normalmodus ausgeschlossen. |
| Q10 Alternativen | Es gab nur einen Weg und keine echte Ausweichroute. | Beste Route berechnen, deren Kanten einzeln ausschließen und günstigsten anderen Weg anbieten; keine vorgetäuschte Alternative bei einem einzigen Weg. |
| Q11 Import-Sicherheit | Breite Übernahme von Metadaten konnte unbekannte Eigenschaften in Zielobjekte übernehmen. | Metadaten-Whitelist; IDs, Zahlen, Farben, Typen, Boolean-Werte, Kantenrückrichtungen, Referenzen und Mengen werden zentral geprüft. Prototype-/Attributtests ergänzt. |
| Q12 Ressourcenbegrenzung | Teilgrenzen waren über Validatoren verteilt; extrem viele Geometriepunkte konnten den Browser belasten. | Einheitliche Datei-/Objekt-/Punktgrenzen; 16-MB-Kartenimport, 1-MB-Raumkatalog und begrenzte Graph-/Polygon-/Straßenbestände. |
| Q13 Dangling references | Entfernte Knoten konnten Straßen-Verknüpfungslisten mit ungültigen IDs hinterlassen. | Verknüpfte Straßenreferenzen beim Löschen lösen; Export/Import validieren Referenzen. |
| Q14 Stale selection | Nach Import/Undo konnten Start und Ziel noch auf alte Objektinstanzen zeigen. | Wiederzuordnung über stabile IDs; verschwundene/ausgeblendete Ziele lösen die Route auf. |
| Q15 Import-Transaktion | Eine teilweise übernommene Raumänderung konnte bei einem späteren Fehler im Katalog stehen bleiben. | Katalog vorprüfen; Fehler rollen den gesamten laufenden Stand zurück. Erfolgreiche Änderungen werden regulär gespeichert. |
| Q16 Konfigurierbarkeit | Raumstammdaten waren mit Bauplan-/Appdaten gekoppelt. | `config/rooms.json`, separater Katalogimport/-export und dauerhafte Raum-Metadaten; neue Ziele/Wege weiter über den Editor. |
| Q17 Kompatibilität | Neue Standardräume konnten ältere lokale Karten unbrauchbar machen. | Katalog-Abgleich ergänzt neue Standardpunkte kontrolliert und erhält vorhandene Geometrie; frühere Nutzerexporte werden auf den Türgraphen migriert. |
| Q18 Ebenen | Später gezeichnete Straßen konnten Route und Wegbeschreibung verdecken. | Straßenbeschriftung als obere Ebene, Route danach; Text-Halo und nicht interaktive Routenstriche. |
| Q19 Klickfläche | Das transparente Bauplan-Wandbild lag über Raumflächen und konnte Klicks abfangen. | Dekorative Wandebene erhält `pointer-events="none"`; zentrale Ereignisbehandlung für Raum-/Zielauswahl. |
| Q20 Ereignisse | Kartenknoten erhielten beim Neuzeichnen erneut zahlreiche Einzelhandler; Pointerup-/Klickpfade waren doppelt. | Ein delegierter Klick-/Tastaturpfad; zweiter Auswahlpfad entfernt. |
| Q21 Gesten | Zoomgrenze war kleiner als die Umgebungsansicht; Pinch mit fast null Abstand war nicht abgesichert. | Passende Zoomspanne bis 6.000 Karteneinheiten, Eingabeprüfung und Pinch-Abstandsschutz; Übergang von zwei Fingern auf einen behandelt. |
| Q22 Rendering | Große Flächenpfade und Suchoperationen wurden bei jedem Zieh-Ereignis erneut berechnet. | Hintergrund-Cache, Room-/Area-Lookups per Map, begrenzte Wandprüfungs-Caches und ein Zeichenauftrag pro Animationsframe; Drag zeigt nur Koordinaten statt alle Formulare neu aufzubauen. |
| Q23 Speicher | Vollständige Undo-Snapshots und wiederholt erzeugte Browserressourcen konnten unnötig viel Speicher halten. | Undo-Historie auf 20 Schritte begrenzt, Objekt-URLs nach Downloads freigegeben, Gestenzustand bei Seitenverlassen geleert. Kein nachgewiesenes dauerhaftes Heap-Leck; eine Heap-Profilierung im Browser steht aus. |
| Q24 Suche | Namenssuche verstand Synonyme schlecht; Maus-spezifische Auswahl behinderte Touch/Tastatur. | Normalisierung von Umlauten/ß, mehrere Suchwörter, Kategorie-Synonyme, Raumnummern-/Gebäuderanking und native Button-Klicks. |
| Q25 Suchfokus | Fokuswechsel in die Vorschlagsliste konnte diese per Blur-Timer ausblenden. | Fokusprüfung auf Eingabe/Vorschlagsliste; Auswahl klappt Combobox konsistent zu. |
| Q26 Dashboard | Kein Startbildschirm mit persönlichem Einstieg vorhanden. | Gebäudeübersicht, zentrale Suche, Schnellziele, Favoriten, Verlauf und Daten-/Verbindungsstatus. |
| Q27 UI/UX | Uneinheitliche Abstände, überladene Werkzeugleisten und fehlende Darstellungsoptionen. | Neues responsives Dashboard, konsistente Karten/Buttons, Hauptnavigation, Hell-/Dunkelumschaltung, sichtbare Routenauswahl und Kioskansicht. |
| Q28 Barrierearme Bedienung | Teile der Karte waren nur per Maus auswählbar; SVG war als einzelnes Bild ausgezeichnet. | SVG als Gruppe, benannte interaktive Raumziele, Enter/Leertaste, Skip-Link, Fokusdarstellung, Reduced-Motion-Regeln und größere Kiosk-Buttons. |
| Q29 Externe Ressourcen | Google-Fonts-Import erzeugte eine externe Anfrage und war offline nicht zuverlässig. | Externer Fontimport entfernt; Systemschrift ohne zusätzliche Laufzeitbibliothek. |
| Q30 Offline | Manuelle Service-Worker-Dateiliste veraltete; Cachebereinigung war nicht auf eigene Caches begrenzt. | Inhaltsabhängige Releaseversion, generierte Dateiliste, nur eigene Cachepräfixe löschen und nur bekannte statische Appdateien bedienen. Kontoseiten oder beliebige private URLs werden nicht abgefangen. |
| Q31 Ladepfad | JSON-Dateien wurden nacheinander geladen; Ladefehler waren wenig handlungsorientiert. | Paralleles Laden, geprüfte HTTP-Antworten, sichtbarer Fehlerzustand mit Neuladen. |
| Q32 Abhängigkeiten | Für die eigentliche App waren keine veralteten installierten npm-Pakete zu aktualisieren; historischer Aufbau erschwerte diese Einordnung. | Null npm-Laufzeitabhängigkeiten beibehalten; `package.json` mit Standardbefehlen und getrennte optionale Python-Werkzeuge dokumentiert. |
| Q33 Generatoren | Wiederverwendung erfolgte teilweise durch Ausführen herausgeschnittener Python-Quelltexte (`exec`). | Gemeinsame Funktionen in `geometry.py`/`blueprint_geometry.py`; normale Imports ohne dynamisches Ausführen von Textausschnitten. |
| Q34 Prüfungen | Frühere Prüfungen testeten teilweise nicht mehr die tatsächliche App und boten keine unabhängige Routingreferenz. | Aktuelle fünfteilige Suite für Kern, Konfiguration, Anwendung, Offline und Quellstruktur; 6.000 Floyd–Warshall-Vergleiche. |
| Q35 Standortdarstellung | Startpunkt und tatsächliche Ortung waren nicht klar als manuelle Auswahl dargestellt. | „Ich bin hier“, sichtbarer Standortmarker und stabile Standort-Links; keine erfundene GPS-/WLAN-Ortung. |

## Sicherheitsbewertung

Die App verarbeitet Karten und lokale Benutzereinstellungen, keine Passwörter oder Backend-Sitzungen. Bestehende private Sichtbarkeit der gehosteten Website bleibt erhalten. Der Quellcode enthält keine eingebetteten Zugangsdaten. Importierte Texte werden vor HTML/SVG-Ausgabe maskiert; Koordinaten, Farben und IDs sind typisiert bzw. eingeschränkt. Eine Content Security Policy blockiert fremde Skripte, Objekte und externe Verbindungen. Inline-Stile bleiben für die dynamische SVG-Darstellung erlaubt.

Ein Konfigurationseditor ist keine serverseitige Benutzerverwaltung: Lokale Änderungen verändern nicht heimlich den gemeinsamen Stand. Für kollaborative Administration wäre ein gesondertes authentifiziertes Backend mit Rollen, Versionskonflikten und Prüfprotokoll erforderlich. Offline-Dateien verbleiben nach erfolgreichem Laden auf dem jeweiligen Gerät; für gemeinsam genutzte Terminals sind Browserprofil und Aufbewahrungsregeln organisatorisch festzulegen.

## Nachweise und Prüfgrenzen

| Prüfung | Ergebnis |
|---|---|
| Syntax aller aktiven JS-Dateien / Service Worker | Erfolgreich |
| HTML: eindeutige IDs, referenzierte statische Dateien, CSP | Erfolgreich |
| Unabhängige Routingreferenz | 6.000 Kostenvergleiche erfolgreich |
| Alternative Route, nicht erreichbare Ziele, Treppen-/Aufzugregeln | Erfolgreich |
| Wandprüfung auf tatsächlichem Schulgraphen | 270/270 angebundene Türen vom Eingangsnetz erreichbar |
| Neu durch Wände verschobene Innenkante | Route erfolgreich abgewiesen |
| Originale Außenknoten/-verbindungen | Koordinaten und bisherige Außenkanten unverändert nachgewiesen |
| Lokales Speichern, erneutes Laden, Reset | Erfolgreich |
| Nutzerexport-Migration | Erfolgreich |
| Raumkatalog-Import, Speicherung, Fehler-Rollback | Erfolgreich |
| Favoriten, Verlauf, Suchsynonyme | Erfolgreich |
| Ungültige Zahlen/Farben, doppelte IDs, fremde Attribute, Prototype-Felder, fehlende Knoten | Abgewiesen bzw. sicher entfernt |
| Service-Worker-Installationsliste, Cachegrenzen, Standort-Query offline | In simulierter Umgebung erfolgreich |
| SVG-Karte | Erfolgreich rasterisiert und visuell geprüft |
| Python-Werkzeuge | Syntaxprüfung erfolgreich |
| Interaktiver Desktop-/Mobilbrowser, Screenreader, echte Offline-/PWA-Installation, Heap-Profil | Noch nicht durchgeführt; vorgesehene Browserumgebung nicht verfügbar |

### Performance-Messung

`docs/benchmark.json` enthält einen reproduzierbaren lokalen Test mit 640 Anfragen auf 764 Knoten: vorherige lineare Auswahl **148,32 ms**, Heap-Kern **71,46 ms**, Verhältnis **2,08**. Gemessen wurde der reine Routing-Kern nach Aufwärmen, ohne Browserrendering und Wandadapter. Das ist kein garantierter Faktor für andere Geräte oder das vollständige UI. Die Alternative benötigt zusätzliche Suchen und kostet mehr Rechenzeit als nur der kürzeste Weg.

## Indoor-Navigationskonzept und offene Datenerfassung

Die Baupläne bleiben die Geometriebasis. Erkannte Türöffnungen und öffentliche Flurabschnitte erhalten Graphanker. Raumlabels werden nur an erreichbare Tür-/Flurpunkte gebunden; vier Treppenkerne verbinden EG/OG. Die manuell bestätigten Gebäudeeingänge verbinden Außen- und Innenknoten. Alle Koordinaten sind schematisch registriert und nicht vermessen.

Noch ohne Raumanschluss:

- EG: A 015, A 001, A 002, A 003, B 007, Sporthalle.
- OG: A 104, A 101, A 102, A 120, D 104, D 106, Sporthalle.

Im Editor sind die 22 offenen Türpunkte sichtbar. Fehlende Verbindungen müssen anhand eines eindeutigen Plans oder vor Ort bestätigt werden. Ein neuer Weg, der gegen die feste Wandmaske verstößt, wird auch bei manuell bestätigter Kante nicht verwendet. Sind Baupläne tatsächlich geändert, muss zunächst die Wandmaske aus dem korrigierten Plan erneuert werden.

## Erweiterungen: umgesetzt oder geprüft

| Erweiterung | Stand / nächste Voraussetzung |
|---|---|
| QR-Standort | Standort-Deep-Links umgesetzt. Mit normaler Smartphonekamera lesbare gedruckte QR-Links möglich; kein integrierter QR-Generator oder Kamerascanner vorgetäuscht. |
| WLAN-Ortung | Nicht als automatische Browserortung umgesetzt. Die Network Information API liefert Verbindungstypen, keine fertige Indoor-Position. Erfordert geeignete Infrastruktur, Messdaten und einen passenden nativen/verwalteten Integrationsweg. |
| Beacons | Erweiterbar über einen Positionsadapter. Web Bluetooth ist nicht browserübergreifend verfügbar; Hardware, Berechtigungskonzept und Kalibrierung fehlen. |
| Touchscreen | Größere Bedienelemente und Gestenbehandlung umgesetzt; echter Gerätetest ausstehend. |
| Kiosk | Umschaltbare Touch-/Kioskansicht, Rückkehr mit Escape. Ein gesperrter Betriebssystem-/Browser-Kiosk benötigt Gerätekonfiguration; Vollbildschutz wird nicht vorgetäuscht. |
| Mehrsprachigkeit | DE/EN-Grundübersetzung des Dashboards umgesetzt. Vollständige Übersetzung aller Editor- und Routenhinweise ist als weiterer Sprachkatalog zu ergänzen. |
| Dark Mode | Hell-/Dunkelumschaltung mit lokaler Präferenz umgesetzt; Karte behält zur Orientierung ihre gewählte Palette. |
| Offline | Versionierter Service Worker mit vollständigem App-Kern umgesetzt; Erstladen/Registrierung online nötig. PDF-Herkunftsdateien werden nicht pauschal für offline gespeichert. |
| Geteilte Admin-Datenbank | Nicht nötig für die aktuelle statische Einzelnutzerkonfiguration. Für gemeinsame Bearbeitung später authentifizierte API plus transaktionale Datenbank und Rollenmodell. |

Aktuelle technische Quellen zur Erweiterungsbewertung, abgerufen am 17.11.2026:

- MDN: [Using Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers)
- MDN: [Network Information API](https://developer.mozilla.org/en-US/docs/Web/API/Network_Information_API)
- MDN: [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
- MDN: [BarcodeDetector](https://developer.mozilla.org/en-US/docs/Web/API/BarcodeDetector)

## Priorisierte Empfehlungen für die Abnahme

1. Offene Türen, Sporthalle und die tatsächlichen Aufzuglandungen vor Ort erfassen; keine simulierten Verbindungen als Freigabe werten.
2. Auf einem Windows-/Chrome-Desktop, iPhone/Safari und Android/Chrome Suche, Kartenklick, Drag, Etagenroute, Favoriten, Import und Offline-Neustart durchspielen.
3. Tastatur- und Screenreader-Abnahme durchführen; Lesbarkeit kleiner Raumlabels in der realen Bildschirm-/Touchgröße prüfen.
4. Erst bei gemeinsamer Administration einen Backenddienst einführen; Authentifizierung und Konfliktauflösung nicht durch bloßes JSON-Schreiben ersetzen.
5. DE/EN-Sprachkatalog vervollständigen und bei künftigem Ausbau den verbleibenden geteilten Frontendzustand in ES-Module überführen.

Die Punkte 1–3 sind reale Abnahme-/Datenlücken. Sie wurden sichtbar dokumentiert und durch gesperrte unbekannte Verbindungen abgesichert, nicht als erledigt ausgegeben.
