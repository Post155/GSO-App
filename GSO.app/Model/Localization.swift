import SwiftUI

enum AppLanguage: String, CaseIterable {
    case de = "de"
    case en = "en"

    var displayName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        }
    }

    var flag: String {
        switch self {
        case .de: return "🇩🇪"
        case .en: return "🇬🇧"
        }
    }
}

enum L {
    @AppStorage("appLanguage") static var current: String = "de"

    static func s(_ key: String) -> String {
        let lang = AppLanguage(rawValue: current) ?? .de
        switch lang {
        case .de: return de[key] ?? key
        case .en: return en[key] ?? key
        }
    }

    // MARK: - German
    private static let de: [String: String] = [
        "tab.nav": "Navigation",
        "tab.3d": "3D Campus",

        // Navigation input
        "nav.whereAreYou": "Wo bist du?",
        "nav.whereToGo": "Wohin möchtest du?",
        "nav.calculate": "Route berechnen",
        "nav.directions": "Wegbeschreibung",
        "nav.steps": "Schritte",
        "nav.selectStart": "Standort wählen",
        "nav.selectEnd": "Ziel wählen",
        "nav.searchRoom": "Raum suchen",
        "nav.floor": "Etage",
        "nav.currentLocation": "Aktueller Standort",
        "nav.gpsHint": "GPS-basiert den nächsten Raum finden",

        // Route output
        "nav.start": "Start",
        "nav.arrived": "Angekommen",
        "nav.approxMin": "Min.",
        "nav.alreadyHere": "Du bist bereits am Ziel!",
        "nav.roomNotFound": "Raum nicht gefunden.",
        "nav.noRoute": "Kein Weg gefunden.",
        "nav.continue": "Weiter",

        // Forward instructions
        "nav.goToCorridorB": "Gehe auf den Flur B",
        "nav.goToMiddleB": "Gehe zur Mittelhalle B",
        "nav.goToCorridorC": "Gehe auf den Flur C",
        "nav.goToMiddleC": "Gehe zur Mittelhalle C",
        "nav.goToCourtyard": "Gehe zum Innenhof",
        "nav.goToStairsBSport": "Gehe zum Treppenhaus B/Sport",
        "nav.goToChangingRoom": "Gehe zur Umkleide",
        "nav.enterGym": "Betrete die Sporthalle",
        "nav.wcRight": "WC rechts",
        "nav.wcLeft": "WC links",
        "nav.goToStairsAB": "Gehe zum Treppenhaus A/B",
        "nav.goToForum": "Gehe zum Forum (A-Trakt)",
        "nav.goToKiosk": "Gehe zum Kiosk / Bibliothek",
        "nav.goToStairsAC": "Gehe zum Treppenhaus A/C",
        "nav.enterCorridorC": "Betrete den C-Trakt Flur",
        "nav.goToStairsCAula": "Gehe zum Treppenhaus C/Aula",
        "nav.enterAula": "Betrete die Aula",
        "nav.crossCourtyardForum": "Gehe über den Hof zum Forum",
        "nav.crossCourtyardGym": "Gehe über den Hof Richtung Sporthalle",
        "nav.crossCourtyardAula": "Gehe über den Hof Richtung Aula",
        "nav.stairsUpExam": "Treppe hoch zum Prüfungsbereich",

        // Reverse instructions
        "nav.goToRoom": "Gehe zu Raum",
        "nav.enterCorridorB": "Betrete den B-Trakt Flur",
        "nav.leaveGym": "Verlasse die Sporthalle",
        "nav.leaveAula": "Verlasse die Aula",
        "nav.goToConnBSport": "Gehe zur Verbindung B/Sport",
        "nav.goToConnAB": "Gehe zur Verbindung A/B",
        "nav.goToConnAC": "Gehe zur Verbindung A/C",
        "nav.goToConnCAula": "Gehe zur Verbindung C/Aula",
        "nav.stairsDownAB": "Treppe runter zur Verbindung A/B",
        "nav.stairsDownAC": "Treppe runter zur Verbindung A/C",

        // Upper floor instructions
        "nav.goToCorridorBOG": "Gehe auf den Flur B (OG)",
        "nav.goToCorridorCOG": "Gehe auf den Flur C (OG)",
        "nav.goToMiddleBOG": "Gehe zur Mittelhalle B (OG)",
        "nav.goToMiddleCOG": "Gehe zur Mittelhalle C (OG)",
        "nav.stairsUpCorridorB": "Treppe hoch zum B-Trakt Obergeschoss",
        "nav.stairsUpCorridorC": "Treppe hoch zum C-Trakt Obergeschoss",
        "nav.stairsDownCorridorB": "Treppe runter zum B-Trakt Erdgeschoss",
        "nav.stairsDownCorridorC": "Treppe runter zum C-Trakt Erdgeschoss",

        // Floor labels
        "nav.floor.eg": "EG",
        "nav.floor.og": "OG",
        "nav.floor.ground": "Erdgeschoss",
        "nav.floor.upper": "Obergeschoss",
        "nav.floorQuestionTitle": "In welchem Stockwerk bist du?",
        "nav.floorQuestionMsg": "Damit der Startpunkt korrekt gewählt wird, gib bitte dein aktuelles Stockwerk an.",

        // Real-time & demo
        "nav.startNav": "Navigation starten",
        "nav.startDemo": "Demo starten",
        "nav.endNav": "Navigation beenden",
        "nav.step": "Schritt",
        "nav.toNextPoint": "zum nächsten Punkt",
        "nav.demoActive": "Demo-Modus",
        "nav.showSteps": "Alle Schritte anzeigen",
        "nav.hideSteps": "Schritte ausblenden",

        // Off campus
        "nav.offCampusTitle": "Nicht auf dem Schulgelände",
        "nav.offCampusMsg": "Du befindest dich gerade nicht auf dem Schulgelände. Bitte wähle deinen Standort manuell aus.",

        // Campus
        "gso.3d": "3D Campus",
        "gso.3dHint": "Drehen & Zoomen",
        "gso.360title": "360° Rundgang",
        "gso.360hint": "Tippe um dich umzuschauen",
        "gso.blockB": "B-Trakt Mitte",
        "gso.blockC": "C-Trakt Mitte",
        "gso.upperA": "A-Trakt Obergeschoss",
        "gso.campusTitle": "Campus",
        "gso.campusSubtitle": "Georg-Simon-Ohm Berufskolleg",
        "gso.stats.students": "Schüler",
        "gso.stats.teachers": "Lehrkräfte",
        "gso.stats.founded": "Gegründet",
        "gso.stats.buildings": "Gebäude",

        // Settings
        "settings.title": "Einstellungen",
        "settings.appearance": "Erscheinungsbild",
        "settings.appearance.system": "System",
        "settings.appearance.light": "Hell",
        "settings.appearance.dark": "Dunkel",
        "settings.done": "Fertig",
        "settings.info": "Entwickelt von Batu, Jonas und Emil",
        "settings.language": "Sprache",
        "settings.accessibility": "Barrierefreiheit",
        "settings.accessibilityToggle": "Navigations-Vorlese-Modus",
        "settings.accessibilityHint": "Wenn aktiviert, liest VoiceOver nur die Navigationsanweisungen vor — nicht die gesamte Benutzeroberfläche.",

        // Nodes
        "node.forum": "Forum / Cafeteria",
        "node.kiosk": "Kiosk & Bibliothek",
        "node.exam": "Prüfungsräume / Sekretariat",
        "node.middleB": "Mittelhalle B",
        "node.middleC": "Mittelhalle C",
        "node.corridorB": "Flur B",
        "node.corridorC": "Flur C",
        "node.connBSport": "Verbindung B/Sporthalle",
        "node.connAB": "Verbindung A/B",
        "node.connAC": "Verbindung A/C",
        "node.connCAula": "Verbindung C/Aula",
        "node.gym": "Sporthalle",
        "node.changingRoom": "Umkleide",
        "node.aula": "Aula",
        "node.courtyard": "Innenhof",
        "node.corridorBOG": "Flur B (OG)",
        "node.corridorCOG": "Flur C (OG)",
        "node.middleBOG": "Mittelhalle B (OG)",
        "node.middleCOG": "Mittelhalle C (OG)",

        // Outdoor / approach
        "node.entrance": "Parkplatz-Eingang",
        "node.mainEntrance": "Haupteingang",
        "node.carParking": "Parkplatz (Auto)",
        "node.bikeParking": "Fahrrad-Stellplatz",
        "node.hofNorth": "Hof Nord",
        "node.hofSouth": "Hof Süd",
        "nav.outdoor": "Außenbereich",
        "nav.toParking": "Gehe zum Parkplatz",
        "nav.toBikeParking": "Gehe zum Fahrrad-Stellplatz",
        "nav.toEntrance": "Gehe zum Parkplatz-Eingang",
        "nav.toMainEntrance": "Gehe zum Haupteingang",
        "nav.fromBikeToBuilding": "Gehe Richtung Schulgebäude",
        "nav.toCourtyardN": "Gehe Richtung Hof Nord",
        "nav.toCourtyardS": "Gehe Richtung Hof Süd",
        "nav.crossCourtyardSouth": "Gehe quer über den Hof Richtung Süden",
        "nav.crossCourtyardNorth": "Gehe quer über den Hof Richtung Norden",
        "nav.continueCorridorB": "Weiter durch den B-Trakt Flur",
        "nav.continueCorridorC": "Weiter durch den C-Trakt Flur",
        "nav.toStairsAB": "Gehe zum Treppenhaus A/B",
        "nav.toStairsBSport": "Gehe zum Treppenhaus B/Sport",
        "nav.toElevatorA": "Gehe zum Aufzug",

        // Named rooms from floor plan
        "node.a001": "A001 – Lager / Kiosk",
        "node.a002": "A002 – Klassenraum",
        "node.a003": "A003 – Lehrerzimmer",
        "node.a007": "A007 – Verkauf",
        "node.e009": "E009",
        "node.e010": "E010",
        "node.d002": "D002 – Stuhllager",
        "node.elevatorA": "Aufzug (A-Trakt)",

        // Hof ring mesh + door entries (NEW)
        "node.hofMesh": "Hof",
        "node.outdoorMesh": "Außenweg",
        "node.doorSporthalle": "Sporthalle Direkteingang",
        "node.doorMensa": "Mensa Eingang (EG)",
        "nav.aroundCourtyard": "Weiter um den Hof herum",
        "nav.toSporthalleDirect": "Direkter Sporthallen-Eingang",
        "nav.toMensaEG": "Gehe zum Mensa Eingang",
    ]

    // MARK: - English
    private static let en: [String: String] = [
        "tab.nav": "Navigation",
        "tab.3d": "3D Campus",

        "nav.whereAreYou": "Where are you?",
        "nav.whereToGo": "Where do you want to go?",
        "nav.calculate": "Calculate Route",
        "nav.directions": "Directions",
        "nav.steps": "Steps",
        "nav.selectStart": "Select Start",
        "nav.selectEnd": "Select Destination",
        "nav.searchRoom": "Search room",
        "nav.floor": "Floor",
        "nav.currentLocation": "Current Location",
        "nav.gpsHint": "Find nearest room via GPS",

        "nav.start": "Start",
        "nav.arrived": "Arrived",
        "nav.approxMin": "min",
        "nav.alreadyHere": "You are already at your destination!",
        "nav.roomNotFound": "Room not found.",
        "nav.noRoute": "No route found.",
        "nav.continue": "Continue",

        "nav.goToCorridorB": "Go to corridor B",
        "nav.goToMiddleB": "Go to middle hall B",
        "nav.goToCorridorC": "Go to corridor C",
        "nav.goToMiddleC": "Go to middle hall C",
        "nav.goToCourtyard": "Go to the courtyard",
        "nav.goToStairsBSport": "Go to staircase B/Gym",
        "nav.goToChangingRoom": "Go to the changing room",
        "nav.enterGym": "Enter the gym",
        "nav.wcRight": "Restroom on the right",
        "nav.wcLeft": "Restroom on the left",
        "nav.goToStairsAB": "Go to staircase A/B",
        "nav.goToForum": "Go to the Forum (Block A)",
        "nav.goToKiosk": "Go to the kiosk / library",
        "nav.goToStairsAC": "Go to staircase A/C",
        "nav.enterCorridorC": "Enter Block C corridor",
        "nav.goToStairsCAula": "Go to staircase C/Auditorium",
        "nav.enterAula": "Enter the auditorium",
        "nav.crossCourtyardForum": "Cross the courtyard to the Forum",
        "nav.crossCourtyardGym": "Cross the courtyard towards the gym",
        "nav.crossCourtyardAula": "Cross the courtyard towards the auditorium",
        "nav.stairsUpExam": "Go upstairs to the exam area",

        "nav.goToRoom": "Go to room",
        "nav.enterCorridorB": "Enter Block B corridor",
        "nav.leaveGym": "Leave the gym",
        "nav.leaveAula": "Leave the auditorium",
        "nav.goToConnBSport": "Go to connection B/Gym",
        "nav.goToConnAB": "Go to connection A/B",
        "nav.goToConnAC": "Go to connection A/C",
        "nav.goToConnCAula": "Go to connection C/Auditorium",
        "nav.stairsDownAB": "Stairs down to connection A/B",
        "nav.stairsDownAC": "Stairs down to connection A/C",

        // Upper floor
        "nav.goToCorridorBOG": "Go to corridor B (upper)",
        "nav.goToCorridorCOG": "Go to corridor C (upper)",
        "nav.goToMiddleBOG": "Go to middle hall B (upper)",
        "nav.goToMiddleCOG": "Go to middle hall C (upper)",
        "nav.stairsUpCorridorB": "Stairs up to Block B upper floor",
        "nav.stairsUpCorridorC": "Stairs up to Block C upper floor",
        "nav.stairsDownCorridorB": "Stairs down to Block B ground floor",
        "nav.stairsDownCorridorC": "Stairs down to Block C ground floor",

        "nav.floor.eg": "GF",
        "nav.floor.og": "UF",
        "nav.floor.ground": "Ground Floor",
        "nav.floor.upper": "Upper Floor",
        "nav.floorQuestionTitle": "Which floor are you on?",
        "nav.floorQuestionMsg": "To pick the right starting point, please tell us which floor you're currently on.",

        "nav.startNav": "Start Navigation",
        "nav.startDemo": "Start Demo",
        "nav.endNav": "End Navigation",
        "nav.step": "Step",
        "nav.toNextPoint": "to next point",
        "nav.demoActive": "Demo Mode",
        "nav.showSteps": "Show all steps",
        "nav.hideSteps": "Hide steps",

        "nav.offCampusTitle": "Not on Campus",
        "nav.offCampusMsg": "You are currently not on the school campus. Please select your location manually.",

        "gso.3d": "3D Campus",
        "gso.3dHint": "Rotate & Zoom",
        "gso.360title": "360° Tour",
        "gso.360hint": "Tap to look around",
        "gso.blockB": "Block B Center",
        "gso.blockC": "Block C Center",
        "gso.upperA": "Block A Upper Level",
        "gso.campusTitle": "Campus",
        "gso.campusSubtitle": "Georg-Simon-Ohm Berufskolleg",
        "gso.stats.students": "Students",
        "gso.stats.teachers": "Teachers",
        "gso.stats.founded": "Founded",
        "gso.stats.buildings": "Buildings",

        "settings.title": "Settings",
        "settings.appearance": "Appearance",
        "settings.appearance.system": "System",
        "settings.appearance.light": "Light",
        "settings.appearance.dark": "Dark",
        "settings.done": "Done",
        "settings.info": "Developed by Batu, Jonas and Emil",
        "settings.language": "Language",
        "settings.accessibility": "Accessibility",
        "settings.accessibilityToggle": "Navigation Read-Aloud Mode",
        "settings.accessibilityHint": "When enabled, VoiceOver only reads navigation instructions — not the entire interface.",

        "node.forum": "Forum / Cafeteria",
        "node.kiosk": "Kiosk & Library",
        "node.exam": "Exam Rooms / Office",
        "node.middleB": "Middle Hall B",
        "node.middleC": "Middle Hall C",
        "node.corridorB": "Corridor B",
        "node.corridorC": "Corridor C",
        "node.connBSport": "Connection B/Gym",
        "node.connAB": "Connection A/B",
        "node.connAC": "Connection A/C",
        "node.connCAula": "Connection C/Auditorium",
        "node.gym": "Gym",
        "node.changingRoom": "Changing Room",
        "node.aula": "Auditorium",
        "node.courtyard": "Courtyard",
        "node.corridorBOG": "Corridor B (Upper)",
        "node.corridorCOG": "Corridor C (Upper)",
        "node.middleBOG": "Middle Hall B (Upper)",
        "node.middleCOG": "Middle Hall C (Upper)",

        // Outdoor / approach
        "node.entrance": "Parking Entrance",
        "node.mainEntrance": "Main Entrance",
        "node.carParking": "Car Parking",
        "node.bikeParking": "Bike Parking",
        "node.hofNorth": "Courtyard North",
        "node.hofSouth": "Courtyard South",
        "nav.outdoor": "Outdoor",
        "nav.toParking": "Go to the parking lot",
        "nav.toBikeParking": "Go to the bike parking",
        "nav.toEntrance": "Go to the parking entrance",
        "nav.toMainEntrance": "Go to the main entrance",
        "nav.fromBikeToBuilding": "Head towards the school building",
        "nav.toCourtyardN": "Head to north courtyard",
        "nav.toCourtyardS": "Head to south courtyard",
        "nav.crossCourtyardSouth": "Cross the courtyard southwards",
        "nav.crossCourtyardNorth": "Cross the courtyard northwards",
        "nav.continueCorridorB": "Continue along Block B corridor",
        "nav.continueCorridorC": "Continue along Block C corridor",
        "nav.toStairsAB": "Go to staircase A/B",
        "nav.toStairsBSport": "Go to staircase B/Gym",
        "nav.toElevatorA": "Go to the elevator",

        // Named rooms from floor plan
        "node.a001": "A001 – Storage / Kiosk",
        "node.a002": "A002 – Classroom",
        "node.a003": "A003 – Staff Room",
        "node.a007": "A007 – Shop",
        "node.e009": "E009",
        "node.e010": "E010",
        "node.d002": "D002 – Chair Storage",
        "node.elevatorA": "Elevator (Block A)",

        // Hof ring mesh + door entries (NEW)
        "node.hofMesh": "Courtyard",
        "node.outdoorMesh": "Outdoor path",
        "node.doorSporthalle": "Gym Direct Entrance",
        "node.doorMensa": "Cafeteria Entrance (GF)",
        "nav.aroundCourtyard": "Continue around the courtyard",
        "nav.toSporthalleDirect": "Direct gym entrance",
        "nav.toMensaEG": "Go to cafeteria entrance",
    ]
}
