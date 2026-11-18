# Räume und Wegenetz konfigurieren

## Raumkatalog

`dist/config/rooms.json` enthält `schemaVersion: 1`, `coordinateSystem: "blueprint"` und ein Array `rooms`.

```json
{
  "id": "dev-raum-a-neu",
  "code": "A Neu",
  "name": "Besprechungsraum",
  "building": "A",
  "floor": "EG",
  "x": 475,
  "y": 700,
  "type": "office",
  "visible": true,
  "important": true
}
```

Die Beispielkoordinaten sind ein **Formatbeispiel**, keine bestätigte Raumposition. Position an der passenden Stelle des Bauplans setzen. Die X-/Y-Werte beziehen sich auf die registrierten Baupläne, nicht auf GPS.

| Feld | Bedeutung |
|---|---|
| `id` | Dauerhafte eindeutige ID; für neue Räume `dev-…` verwenden |
| `code`, `name` | Kurzname und ausführliche Beschreibung, maximal 160 Zeichen |
| `building` | Gebäudetrakt, beispielsweise A–D |
| `floor` | EG oder OG |
| `x`, `y` | Bauplanposition |
| `type` | `classroom`, `office`, `service`, `wc`, `stairs`, `lift`, `corridor`; weitere Zielkategorien siehe Prüfer |
| `visible` | Sichtbarkeit in Karte/Suche |
| `important` | Anzeige bei aktiviertem Filter „Wichtige Räume zuerst“ |
| `region` | Optional: vorhandene Raumflächen-ID des jeweiligen Bauplans |
| `node` | Optional im importierten Katalog: bestehender Wegpunkt der gleichen Etage für einen neuen Raum |

Es werden keine Kantine, Notausgänge oder Empfangsräume anhand bloßer Vermutung benannt. Bereits bekannte Büros/WC/Treppen und wichtige Ziele sind verfügbar. Solche weiteren Raumarten können als passende Kategorie mit eindeutiger Bezeichnung ergänzt werden, sobald Lage und Funktion bestätigt sind.

## Ohne Programmierung arbeiten

1. Karte öffnen → Entwicklermodus.
2. **Zielpunkte:** Markierungen verschieben, benennen und einer Kategorie zuordnen. Für einen zusätzlichen Raum „Markierung setzen“, aktuelle Etage wählen und anschließend den Punkt bearbeiten.
3. **Wege:** Wegpunkte setzen, verbinden, Verbindungen löschen und zusätzliche Eckpunkte einfügen. Zum Etagenwechsel den Typ Treppe/Aufzug, für Gelände ↔ EG den Typ Tür verwenden und den geprüften Übergang bestätigen.
4. **Flächen:** Bestehende Flächen/Eckpunkte bearbeiten, Masken zeichnen oder als Sperrfläche kennzeichnen.
5. **Straßen/Bäume:** Verlauf, Breite, Farbe, Beschriftung bzw. Krone ändern. Ein gezeichneter Gehweg wird erst über „Als Gehweg ins Wegenetz übernehmen“ routbar.
6. Lokal speichern. Mit **JSON exportieren** den gesamten Stand sichern.
7. Raumkatalog separat importieren/exportieren, wenn nur Raumstammdaten geändert werden sollen. Ein ausgelassener vorhandener Raum wird ausgeblendet. Ein nicht angeschlossener neuer Raum bleibt ohne Route.

Das vollständige Editorformat bleibt Version 4. Es enthält `points`, `pointNodes`, `pointMeta`, `customPlaces`, `hiddenPoints`, `nodes`, `areas`, `scenery` und optional `roomDefinitions`. Neue Metadaten für Gebäudetrakt und Wichtigkeit werden mitgespeichert. Beim Rückgängig/Import werden Start und Ziel anhand ihrer IDs neu zugeordnet.

## Veröffentlichten Ausgangsstand ändern

Gesamtexport nach Prüfung als `dist/config/campus.json` übernehmen. Separat gepflegte Standardräume stehen in `rooms.json`; dortige Stammdaten bestimmen den frischen veröffentlichten Stand. Neue Standardräume erhalten bei vorhandenen älteren lokalen Karten die Standardmetadaten; die bisherige manuell bearbeitete Geometrie wird nicht pauschal zurückgesetzt. Neue Wege werden nicht automatisch aus Straßen oder Gebäudeflächen geraten.

Anschließend `npm test` und `npm run build` ausführen und `dist/` veröffentlichen. Die Python-Werkzeuge dienen ausschließlich zur erneuten Gewinnung aus Vorlagen und sind für alltägliche Änderungen nicht erforderlich.

## Standort-Links und QR-Codes

Raum öffnen → „Standort-Link“. Der Link enthält nur `?location=<Ziel-ID>`. Beim Öffnen wird der bekannte Ort als manuell bestätigter Startpunkt dargestellt. Der Link lässt sich mit einem beliebigen vertrauenswürdigen QR-Druckwerkzeug als Schild drucken und mit der normalen Smartphonekamera öffnen. Keine zusätzlichen Kamera- oder Bluetoothrechte sind nötig. Ein unbekannter Standort-Link erzeugt keine erfundene Position.

## Zentrale App-Einstellungen

`dist/config/app.json` enthält freistehende, nicht geometrische Darstellungseinstellungen:

- `release`: sichtbarer Veröffentlichungsstand und Lade-/Fehlertexte;
- `maps.school`: Standardansicht der Campuskarte;
- `maps.neighbourhood`: Standardansicht der Umgebungskarte.

Die Datei wird beim Start geprüft und ist Teil der Offline-Dateiliste. Ungültige Ansichten oder fehlende Statustexte verhindern den Start kontrolliert; bestehende Karten-, Raum- und Routingdaten bleiben davon getrennt.
