# Architektur

## Verantwortlichkeiten

| Schicht | Dateien | Verantwortung |
|---|---|---|
| Bootstrap | `dist/js/app.js` | Paralleles Laden, kontrollierte Initialisierung, Ereignisbindung |
| Konfiguration | `core/configuration.js` | Typen, Grenzen, Referenzen, Metadaten-Whitelist; keine DOM-Abhängigkeit |
| Zustand | `core/state.js` | Graph, Auswahl, Kartenansicht, Hilfsfunktionen |
| Navigation | `navigation/engine.js` | Min-Heap-Dijkstra und eine echte alternative Route; ohne DOM |
| Routingadapter | `navigation/routing.js` | Wände, Sperrflächen, Treppen/Aufzüge, Weganweisungen |
| Karte | `map/` | SVG-Geometrie, Ebenen, Skalierung, Gesten, Standortmarker |
| Editor | `editor/` | Werkzeuge, kontrollierte Initialisierung, Undo/Redo, Import/Export |
| Oberfläche | `ui/` | Dashboard, Favoriten, Verlauf, Suche, Raumkarten und Raumkatalog |
| Offline | `sw.js` | Generierte, versionierte Liste aus `scripts/build.cjs` |

Die früheren 12 direkt geladenen JavaScript-Dateien mit wechselnden Überschreibungen wurden durch 17 fachlich benannte Dateien ersetzt. Einstieg und Bindungen werden einmal ausgeführt. Editorhilfen mit den Suffixen `Base1`/`Base2` sind explizit benannte Teiloperationen für Punkte, Flächen und Straßen; sie überschreiben keine globalen Funktionen mehr.

Die App ist bewusst statisch. Es gibt kein Backend, das nur zum Verteilen derselben JSON-Dateien benötigt würde. Frontenddarstellung und Navigationskern sind getrennt; der Kern ist auch mit `require()` unabhängig testbar. Fachfunktionen werden in fester Reihenfolge durch lokale, mit `defer` geladene Skripte bereitgestellt. Das reduziert Migrationsrisiken für den bestehenden Editor. Eine spätere Umstellung auf ES-Module mit vollständig gekapseltem Zustand bleibt eine mögliche Folgestufe; sie wird nicht als bereits erledigt behauptet.

## Initialisierung und Persistenz

1. Sieben Konfigurationsdateien parallel laden.
2. Raumkatalog prüfen, Gebäude-/Tür-/Wanddaten einrichten.
3. Katalog mit dem veröffentlichten Ausgangsstand abgleichen.
4. Lokalen gespeicherten Stand prüfen und migrieren oder den veröffentlichten Stand laden; fehlerhafte lokale Originaldatei nicht löschen.
5. Editor-, Karten- und UI-Ereignisse einmal binden.
6. Dashboard anzeigen, gegebenenfalls Standort-Link anwenden und Service Worker registrieren.

`gso-campus-completed-workspace-v1` bleibt der Karten-Speicherschlüssel. `gso-preferences-v1` enthält ausschließlich Favoriten, Verlauf und Darstellungspräferenzen. JSON-Import und Katalogimport verändern den laufenden Stand erst nach Prüfung bzw. rollen eine fehlgeschlagene Katalogoperation zurück. Standort und Routenauswahl werden über stabile Ziel-IDs behandelt.

## Navigation

Knoten tragen ID, Etage, Weltkoordinaten und Kanten. Kanten tragen Ziel, Typ und Bestätigung; geometrische Kosten werden aus den aktuellen Koordinaten neu berechnet. Treppen bekommen einen zusätzlichen Übergangszuschlag. Die Kosten sind **keine Meter oder Minuten**.

Die kürzeste Route verwendet Dijkstra mit Min-Heap und veralteten Heap-Einträgen als überspringbaren Duplikaten. Für eine Alternative wird jede Kante der besten Route einzeln ausgeschlossen; der günstigste dabei gefundene andere Weg wird angeboten. Gibt es keinen anderen Weg, wird keine Alternative erfunden.

Ein unbestätigter Ebenenwechsel ist nicht routbar. Im stufenfreien Modus werden Treppen ausgeschlossen; sonst werden Aufzüge ausgelassen. Ein nicht bestätigter Aufzuganschluss wird nicht durch eine vermutete Verbindung ersetzt.

## Wandprüfung

Aus den PDF-Zeichenebenen `Wand`, `Wand Trockenbau`, `Stütze`, `Fenster` und den expliziten Türöffnungen stammt ein Raster pro Etage mit 1.050 × 744 Zellen. Freie Zellen sind platzsparend bitgepackt. Die inverse affine Registrierung übersetzt bearbeitete Weltkoordinaten zurück ins Raster. Segmente werden mit dichter Abtastung und Prüfung beider Nachbarzellen bei diagonalen Zellwechseln geprüft. Die Rundung an Halbzellen ist deterministisch und mit dem Python-Compiler abgestimmt. Für aus gerundeten Weltkoordinaten rekonstruierte Rastermittelpunkte gilt eine kleine numerische Toleranz; Wände werden dabei nicht pauschal freigegeben.

Ergebnisse sind je Geometrie zwischengespeichert, begrenzt auf 12.000 Einträge. Geänderte Geometrie oder Sperrflächen leeren den Cache. Zusätzlich werden frei eingezeichnete Sperrpolygone geprüft. Der Wandtest ist an die mitgelieferten Baupläne und deren Registrierung gebunden; er ersetzt keine Ortsbegehung und keine Freigabe als Fluchtwegesystem.
