# Bauplan- und Kartengewinnung

Diese Werkzeuge werden **nicht beim App-Start oder Build** ausgeführt. Sie dokumentieren die Herkunft der Zeichnung. Ihr Ergebnis muss vor Übernahme geprüft werden; einzelne Generatoren ersetzen Zwischenstände.

- `build_indoor_navigation.py`: Türen/Wände aus PDF-Zeichenebenen, Fluranker, Übergänge und Wandraster. Aktualisiert den Türkatalog und die Wandmaske unter `dist/config/`; Änderungen am eigentlichen Laufzeitgraphen werden nach Prüfung explizit in `campus.json` übernommen.
- `complete_campus.py`, `finish_user_map.py`: Abgleich ausschließlich mit „Neue Region – Karte“ und Erhalt der manuellen Ausgangszeichnung.
- `straighten_areas.py`, `polish_landscape.py`: Bereinigung erzeugter Polygone; `geometry.py` enthält gemeinsame Geometrie ohne Schreiboperationen beim Import.
- `generate.py`, `refine.py`, `trace_reference.py`: Herkunftswerkzeuge der ursprünglichen Bauplan-/Kartenextraktion; nicht Teil des Laufzeitpfads.

Aus dem Projektverzeichnis starten. Abhängigkeiten für diese optionalen Werkzeuge: Python, NumPy, SciPy, Pillow und PyMuPDF (`fitz`). Sie werden von der Web-App nicht benötigt. Die Werkzeuge benutzen die mitgelieferten Quelldateien unter `dist/assets/`. Vor einer Neugenerierung den aktuellen Kartenstand exportieren und Änderungen versionieren.
