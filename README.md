# GSO App – Campus-Navigation

iOS-App (SwiftUI) für das Schulgelände der GSO an der Westerwaldstraße in Köln. Die App hilft
Schülerinnen, Schülern und Besuchern, Räume, Treppenhäuser, WCs, Aula, Sporthalle und Parkplätze
zu finden – mit einer Navigation im Stil von Apple Karten direkt auf dem Satellitenbild.

## Funktionen

- **Navigation** – Start und Ziel wählen (Raum, WC, Eingang, Parkplatz …) oder den eigenen
  Standort per GPS bestimmen. Die Route wird auf der Karte gezeichnet und Schritt für Schritt
  beschrieben („Gehe auf den Flur B“, „Gehe über den Hof zum C-Trakt“, „Nimm die Treppe ins
  Obergeschoss“ …). Live-Navigation mit GPS sowie ein Demo-Modus.
- **Erdgeschoss / Obergeschoss** – Umschalter für die Raum-Markierungen beider Etagen.
- **3D Campus** – 3D-Modell der Schule (`school_model.usdz`) und 360°-Ansichten ausgewählter Bereiche.
- **Einstellungen** – Deutsch / Englisch und ein Barrierefreiheitsmodus (VoiceOver-Ansagen).

## Wie das Routing funktioniert

Die Routen werden nicht über handgesetzte Punkte berechnet, sondern auf einem Begehbarkeits-Raster
(0,25 m pro Zelle), das aus dem CAD-Grundriss der Schule erzeugt wird:

1. Wände, Fenster, Stützen und Türen werden aus den Ebenen des Grundriss-PDFs ausgelesen.
2. Der Plan wird über die Gebäudeecken auf GPS-Koordinaten gelegt (Abweichung < 0,5 m).
3. Begehbar sind nur Gebäude-Innenräume, der Hof (ohne die Vertiefung in der Mitte) und die
   Außenwege. Gebäude sind nur über die tatsächlich genutzten Eingänge erreichbar
   (Mensa-Eingang, Treppenhäuser, Mittelhallen B/C, Sporthalle, Aula-Foyer).
4. Die App sucht die Route mit A* auf diesem Raster und glättet sie – Routen können dadurch
   nie durch Wände führen.

| Datei | Inhalt |
|---|---|
| `GSO.app/Model/SchoolGridRouter.swift` | A*-Routing, Glättung, Wegbeschreibung |
| `GSO.app/Model/SchoolGrid.bin` | vorberechnetes Raster (EG + OG) |
| `Tools/school-grid/build_school_grid.py` | erzeugt `SchoolGrid.bin` neu aus dem Grundriss-PDF |
| `GSO.app/Views/Campus/IndoorNavView.swift` | Karte, Räume/Orte, Navigations-Oberfläche |

Raster neu erzeugen (z. B. nach Änderungen am Plan oder an den Außenwegen):

```
python3 Tools/school-grid/build_school_grid.py pfad/zum/LS3.1_M01_GSO_Westerwaldstr_EG.pdf
```

Hinweis: Für das Obergeschoss liegt noch kein Plan vor – es wird derzeit wie das Erdgeschoss angenommen.

## Voraussetzungen

- Xcode 26.2 oder neuer, iOS 26.2+
- Projekt `GSO.app.xcodeproj` öffnen und auf Simulator oder iPhone ausführen
