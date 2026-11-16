import SwiftUI
import MapKit
import CoreLocation
import Combine

#Preview {
    IndoorNavView()
}

// ============================================================
// MARK: - Data Types
// ============================================================

struct GeoCoord {
    let lat: Double
    let lon: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

struct NavNode: Identifiable, Hashable {
    let id: String
    let displayNameKey: String
    let block: String
    let floor: Int
    let coordinate: GeoCoord
    let category: NodeCategory
    let isNavigable: Bool

    var displayName: String { L.s(displayNameKey) }

    enum NodeCategory: String, CaseIterable {
        case room, staircase, elevator, hallway, toilet, entrance, courtyard, sport, special, food, parking, bike
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NavNode, rhs: NavNode) -> Bool { lhs.id == rhs.id }
}

struct NavStep: Identifiable {
    let id = UUID()
    let instruction: String
    let icon: String
    let coordinate: GeoCoord?
    let pathCoordinates: [GeoCoord]
    let floor: Int
}

// ============================================================
// MARK: - School Graph
// ============================================================

enum SchoolGraph {

    // Developer diagnostics. Keep false for production; set true to print the zone sequence
    // of every computed route in the Xcode console.
    static let routeDebugLoggingEnabled = false
    static let showDebugNodesOnMap = false

    static let campusCenter = GeoCoord(lat: 50.927609, lon: 6.995676)
    static let campusRadius: Double = 250

    struct BuildingOutline: Identifiable {
        let id: String
        let corners: [GeoCoord]
        let color: Color
    }

    // MARK: - Outdoor areas (parking, paths, gate)

    struct AreaPolygon: Identifiable {
        let id: String
        let corners: [GeoCoord]
        let fillColor: Color
        let strokeColor: Color
        let fillOpacity: Double
    }

    static let outdoorAreas: [AreaPolygon] = [
        // Bike parking
        AreaPolygon(id: "BikeParking", corners: [
            GeoCoord(lat: 50.928101648083896, lon: 6.996307660739916),
            GeoCoord(lat: 50.927941502740026, lon: 6.996154406435238),
            GeoCoord(lat: 50.92780728526492,  lon: 6.996548028016434),
            GeoCoord(lat: 50.927973023454484, lon: 6.996688376695545),
        ], fillColor: .blue, strokeColor: .blue, fillOpacity: 0.18),

        // Car parking
        AreaPolygon(id: "CarParking", corners: [
            GeoCoord(lat: 50.92775557778822, lon: 6.996807914799405),
            GeoCoord(lat: 50.9269160358763,  lon: 6.996062112314206),
            GeoCoord(lat: 50.92674932718177, lon: 6.996495773823369),
            GeoCoord(lat: 50.92761290178794, lon: 6.997229662530543),
        ], fillColor: Color(white: 0.55), strokeColor: Color(white: 0.4), fillOpacity: 0.20),

        // Entrance gate area
        AreaPolygon(id: "EntranceGate", corners: [
            GeoCoord(lat: 50.92704782030103, lon: 6.9974261762042715),
            GeoCoord(lat: 50.92703666992767, lon: 6.997505635766942),
            GeoCoord(lat: 50.92709569831126, lon: 6.997526446855147),
            GeoCoord(lat: 50.92715069049905, lon: 6.997536852398127),
            GeoCoord(lat: 50.9271602762866,  lon: 6.99748322382726),
            GeoCoord(lat: 50.92718496937832, lon: 6.99746282301038),
        ], fillColor: .green, strokeColor: .green, fillOpacity: 0.30),

        // Path: gate → car parking
        AreaPolygon(id: "PathToParking", corners: [
            GeoCoord(lat: 50.9272266859447,    lon: 6.996836282450289),
            GeoCoord(lat: 50.92717633789249,   lon: 6.996787324610494),
            GeoCoord(lat: 50.92707970196233,   lon: 6.997091378558878),
            GeoCoord(lat: 50.927039910638655,  lon: 6.997484329635284),
            GeoCoord(lat: 50.92709188297303,   lon: 6.99749205982107),
            GeoCoord(lat: 50.92713492251826,   lon: 6.997109415657604),
        ], fillColor: Color(white: 0.65), strokeColor: Color(white: 0.4), fillOpacity: 0.25),

        // Main entrance area (foot/bike, north)
        AreaPolygon(id: "HauptEingangArea", corners: [
            GeoCoord(lat: 50.928806588534684, lon: 6.996609537687675),
            GeoCoord(lat: 50.928510822560156, lon: 6.99635737754943),
            GeoCoord(lat: 50.92843529547949,  lon: 6.99657201632786),
            GeoCoord(lat: 50.92873354451595,  lon: 6.996831395492734),
        ], fillColor: .green, strokeColor: .green, fillOpacity: 0.30),

        // Path: main entrance → school grounds (zone before bike parking)
        AreaPolygon(id: "MainPathToSchool", corners: [
            GeoCoord(lat: 50.9288065475572,  lon: 6.996610096477525),
            GeoCoord(lat: 50.92824127478647, lon: 6.996141247240018),
            GeoCoord(lat: 50.92817243057186, lon: 6.996345938719827),
            GeoCoord(lat: 50.92873123346905, lon: 6.996833024792721),
        ], fillColor: Color(white: 0.65), strokeColor: Color(white: 0.4), fillOpacity: 0.25),

        // Path: gate → bike parking (foot path to school)
        AreaPolygon(id: "PathToBike", corners: [
            GeoCoord(lat: 50.92712621931085,   lon: 6.997502056268701),
            GeoCoord(lat: 50.92716015834279,   lon: 6.997509934016136),
            GeoCoord(lat: 50.92716533734128,   lon: 6.997465696988485),
            GeoCoord(lat: 50.92722181233583,   lon: 6.997470305190774),
            GeoCoord(lat: 50.92771755456738,   lon: 6.997308569450354),
            GeoCoord(lat: 50.92776646939751,   lon: 6.99724014929609),
            GeoCoord(lat: 50.9279012501398,    lon: 6.996888533975891),
            GeoCoord(lat: 50.927853064068415,  lon: 6.996851890038272),
            GeoCoord(lat: 50.927696804386756,  lon: 6.9972624229661164),
            GeoCoord(lat: 50.92724123669112,   lon: 6.997410405505548),
            GeoCoord(lat: 50.92714390622186,   lon: 6.997401893678017),
        ], fillColor: Color(white: 0.65), strokeColor: Color(white: 0.4), fillOpacity: 0.25),

        // ── User-supplied walkable zones (for routing-mesh derivation) ──

        // Bike parking → school grounds (foot/bike approach to building)
        AreaPolygon(id: "BikeToSchoolPath", corners: [
            GeoCoord(lat: 50.92789965855073,  lon: 6.996886121946488),
            GeoCoord(lat: 50.92795507425234,  lon: 6.996721130828803),
            GeoCoord(lat: 50.92781070788604,  lon: 6.99659459473196),
            GeoCoord(lat: 50.92800842365628,  lon: 6.995966223998863),
            GeoCoord(lat: 50.927753499384124, lon: 6.995743375749953),
            GeoCoord(lat: 50.927722729788485, lon: 6.9958344918401),
            GeoCoord(lat: 50.92794294492086,  lon: 6.996016215167316),
            GeoCoord(lat: 50.92773912436883,  lon: 6.996621461345143),
            GeoCoord(lat: 50.92789036182029,  lon: 6.996746568127776),
            GeoCoord(lat: 50.927852568172085, lon: 6.996844024306398),
        ], fillColor: Color(white: 0.65), strokeColor: Color(white: 0.4), fillOpacity: 0.20),

        // Hof — full walkable surface (excluding the central platform!)
        AreaPolygon(id: "HofWalkable", corners: [
            GeoCoord(lat: 50.927890765598846, lon: 6.995414190890216),
            GeoCoord(lat: 50.92739763781816,  lon: 6.994988515521101),
            GeoCoord(lat: 50.92735812371245,  lon: 6.995083623413535),
            GeoCoord(lat: 50.92740828096035,  lon: 6.995125428977616),
            GeoCoord(lat: 50.92721311812437,  lon: 6.995691086957692),
            GeoCoord(lat: 50.927149163271565, lon: 6.9956612135003695),
            GeoCoord(lat: 50.927114370900654, lon: 6.995748409403461),
            GeoCoord(lat: 50.92722439478601,  lon: 6.995831600025156),
            GeoCoord(lat: 50.92725755169306,  lon: 6.99574900876263),
            GeoCoord(lat: 50.927289293151716, lon: 6.995783451089295),
            GeoCoord(lat: 50.92725149517017,  lon: 6.9958952597446284),
            GeoCoord(lat: 50.92754953622068,  lon: 6.996143498548946),
            GeoCoord(lat: 50.92754244209556,  lon: 6.996179622902673),
            GeoCoord(lat: 50.927615368392026, lon: 6.996232683576125),
        ], fillColor: .green, strokeColor: .green.opacity(0.6), fillOpacity: 0.10),

        // Way from south up to Haupteingang gate
        AreaPolygon(id: "WayToMainEntrance", corners: [
            GeoCoord(lat: 50.9287720153126,   lon: 6.996700100776934),
            GeoCoord(lat: 50.92777861372335,  lon: 6.995773659766144),
            GeoCoord(lat: 50.92774632749925,  lon: 6.995871374262379),
            GeoCoord(lat: 50.9287542051479,   lon: 6.996757056587796),
        ], fillColor: Color(white: 0.65), strokeColor: Color(white: 0.4), fillOpacity: 0.20),
    ]

    // ── Forbidden zone in the Hof — central platform; routing must NEVER cross ──
    static let forbiddenAreas: [AreaPolygon] = [
        AreaPolygon(id: "HofPlatform", corners: [
            GeoCoord(lat: 50.92754595700282,  lon: 6.995254573526239),
            GeoCoord(lat: 50.927475645325586, lon: 6.995237216699991),
            GeoCoord(lat: 50.9273940250271,   lon: 6.99534321589951),
            GeoCoord(lat: 50.92736981770298,  lon: 6.995497507117534),
            GeoCoord(lat: 50.927373815961886, lon: 6.995680046469914),
            GeoCoord(lat: 50.927419206186755, lon: 6.995826789500882),
            GeoCoord(lat: 50.92749010633014,  lon: 6.995944771414372),
            GeoCoord(lat: 50.9275703918768,   lon: 6.995977111207537),
            GeoCoord(lat: 50.92764882196363,  lon: 6.995901626691449),
            GeoCoord(lat: 50.92768956702275,  lon: 6.995695387139932),
            GeoCoord(lat: 50.927650049321414, lon: 6.9954082950581835),
        ], fillColor: .red, strokeColor: .red.opacity(0.7), fillOpacity: 0.18),
    ]

    static let buildingOutlines: [BuildingOutline] = [
        BuildingOutline(id: "A", corners: [
            GeoCoord(lat: 50.927031, lon: 6.995527), GeoCoord(lat: 50.927217, lon: 6.994987),
            GeoCoord(lat: 50.927382, lon: 6.995130), GeoCoord(lat: 50.927196, lon: 6.995670)
        ], color: .yellow),
        BuildingOutline(id: "B", corners: [
            GeoCoord(lat: 50.927245, lon: 6.994809), GeoCoord(lat: 50.927319, lon: 6.994594),
            GeoCoord(lat: 50.927906, lon: 6.995103), GeoCoord(lat: 50.927832, lon: 6.995318)
        ], color: .green),
        BuildingOutline(id: "C", corners: [
            GeoCoord(lat: 50.926879, lon: 6.995879), GeoCoord(lat: 50.926955, lon: 6.995660),
            GeoCoord(lat: 50.927532, lon: 6.996160), GeoCoord(lat: 50.927456, lon: 6.996379)
        ], color: .cyan),
        BuildingOutline(id: "Sport", corners: [
            GeoCoord(lat: 50.927801, lon: 6.995750), GeoCoord(lat: 50.927995, lon: 6.995188),
            GeoCoord(lat: 50.928328, lon: 6.995477), GeoCoord(lat: 50.928135, lon: 6.996039)
        ], color: .pink),
        BuildingOutline(id: "Aula", corners: [
            GeoCoord(lat: 50.927557, lon: 6.996463), GeoCoord(lat: 50.927659, lon: 6.996169),
            GeoCoord(lat: 50.927825, lon: 6.996313), GeoCoord(lat: 50.927723, lon: 6.996607)
        ], color: .orange),
    ]

    // MARK: - Physical wall line supplied by the user
    // GeoJSON uses lon/lat. These coordinates are converted to lat/lon here.
    // This is NOT rendered in production (only with showDebugNodesOnMap). Its outer
    // corners are the GPS control points used to georeference the CAD floor plan
    // in Tools/school-grid/build_school_grid.py.
    static let physicalWallLine: [GeoCoord] = [
        GeoCoord(lat: 50.92791861090339,  lon: 6.9960400576444215),
        GeoCoord(lat: 50.92772137609089,  lon: 6.996614404477441),
        GeoCoord(lat: 50.926874053924394, lon: 6.995886676469439),
        GeoCoord(lat: 50.927315308262735, lon: 6.994597843014191),
        GeoCoord(lat: 50.92833305485223,  lon: 6.995471398538427),
        GeoCoord(lat: 50.9281395831955,   lon: 6.996034890194494),
        GeoCoord(lat: 50.92780631052577,  lon: 6.995747031810026),
        GeoCoord(lat: 50.927922570795346, lon: 6.995396085566085),
        GeoCoord(lat: 50.92743213700268,  lon: 6.994990941853644),
        GeoCoord(lat: 50.92714961844507,  lon: 6.995821686879452),
        GeoCoord(lat: 50.927629931693104, lon: 6.99624061826313),
        GeoCoord(lat: 50.92774940915902,  lon: 6.995900959272177),
        GeoCoord(lat: 50.9279193631869,   lon: 6.996037886609514),
    ]


    // MARK: - Ground Floor Nodes
    static let groundFloorNodes: [NavNode] = [
        // A Block
        NavNode(id: "A-Forum", displayNameKey: "node.forum", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927206, lon: 6.995329), category: .food, isNavigable: true),
        NavNode(id: "A-Kiosk", displayNameKey: "node.kiosk", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927213, lon: 6.995509), category: .special, isNavigable: true),
        NavNode(id: "A-Exam", displayNameKey: "node.exam", block: "A", floor: 1,
                coordinate: GeoCoord(lat: 50.927166, lon: 6.995294), category: .room, isNavigable: true),

        // B Block ground floor
        NavNode(id: "B1",  displayNameKey: "B013",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927848, lon: 6.995116), category: .room, isNavigable: true),
        NavNode(id: "B2",  displayNameKey: "B017",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927808, lon: 6.995242), category: .room, isNavigable: true),
        NavNode(id: "B3",  displayNameKey: "B011",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927753, lon: 6.995036), category: .room, isNavigable: true),
        NavNode(id: "B4",  displayNameKey: "B019",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927711, lon: 6.995161), category: .room, isNavigable: true),
        NavNode(id: "B5",  displayNameKey: "B009",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927659, lon: 6.994956), category: .room, isNavigable: true),
        NavNode(id: "B6",  displayNameKey: "B021",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927616, lon: 6.995078), category: .room, isNavigable: true),
        NavNode(id: "B7",  displayNameKey: "B005",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927531, lon: 6.994831), category: .room, isNavigable: true),
        NavNode(id: "B8",  displayNameKey: "B022/B023/B024",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927484, lon: 6.994967), category: .room, isNavigable: true),
        NavNode(id: "B9",  displayNameKey: "B003/B004",  block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927436, lon: 6.994749), category: .room, isNavigable: true),
        NavNode(id: "B10", displayNameKey: "B022/B023/B024", block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927384, lon: 6.994894), category: .room, isNavigable: true),
        NavNode(id: "B11", displayNameKey: "B001", block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927341, lon: 6.994667), category: .room, isNavigable: true),
        NavNode(id: "B12", displayNameKey: "B025/B026", block: "B", floor: 0, coordinate: GeoCoord(lat: 50.927293, lon: 6.994803), category: .room, isNavigable: true),

        // C Block ground floor
        NavNode(id: "C1",  displayNameKey: "C009",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927487, lon: 6.996176), category: .room, isNavigable: true),
        NavNode(id: "C2",  displayNameKey: "C013",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927443, lon: 6.996303), category: .room, isNavigable: true),
        NavNode(id: "C3",  displayNameKey: "C007",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927388, lon: 6.996098), category: .room, isNavigable: true),
        NavNode(id: "C4",  displayNameKey: "C015",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927347, lon: 6.996219), category: .room, isNavigable: true),
        NavNode(id: "C5",  displayNameKey: "C005",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927294, lon: 6.996017), category: .room, isNavigable: true),
        NavNode(id: "C6",  displayNameKey: "C017",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927250, lon: 6.996145), category: .room, isNavigable: true),
        NavNode(id: "C7",  displayNameKey: "C004",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927163, lon: 6.995897), category: .room, isNavigable: true),
        NavNode(id: "C8",  displayNameKey: "C021",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927117, lon: 6.996030), category: .room, isNavigable: true),
        NavNode(id: "C9",  displayNameKey: "C002",  block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927067, lon: 6.995815), category: .room, isNavigable: true),
        NavNode(id: "C10", displayNameKey: "C023", block: "C", floor: 0, coordinate: GeoCoord(lat: 50.927023, lon: 6.995949), category: .room, isNavigable: true),
        NavNode(id: "C11", displayNameKey: "C001", block: "C", floor: 0, coordinate: GeoCoord(lat: 50.926973, lon: 6.995736), category: .room, isNavigable: true),
        NavNode(id: "C12", displayNameKey: "C025", block: "C", floor: 0, coordinate: GeoCoord(lat: 50.926928, lon: 6.995866), category: .room, isNavigable: true),

        // Hallway / connection nodes
        // Corridors split into N/M/S so rooms near the stairs route directly there
        // (instead of detouring to the middle of the corridor first)
        NavNode(id: "FlurB-N", displayNameKey: "node.corridorB", block: "B", floor: 0,
                coordinate: GeoCoord(lat: 50.927780, lon: 6.995040), category: .hallway, isNavigable: false),
        NavNode(id: "FlurB-M", displayNameKey: "node.corridorB", block: "B", floor: 0,
                coordinate: GeoCoord(lat: 50.927576, lon: 6.994962), category: .hallway, isNavigable: false),
        NavNode(id: "FlurB-S", displayNameKey: "node.corridorB", block: "B", floor: 0,
                coordinate: GeoCoord(lat: 50.927360, lon: 6.994830), category: .hallway, isNavigable: false),

        NavNode(id: "FlurC-N", displayNameKey: "node.corridorC", block: "C", floor: 0,
                coordinate: GeoCoord(lat: 50.927450, lon: 6.996150), category: .hallway, isNavigable: false),
        NavNode(id: "FlurC-M", displayNameKey: "node.corridorC", block: "C", floor: 0,
                coordinate: GeoCoord(lat: 50.927214, lon: 6.996030), category: .hallway, isNavigable: false),
        NavNode(id: "FlurC-S", displayNameKey: "node.corridorC", block: "C", floor: 0,
                coordinate: GeoCoord(lat: 50.927000, lon: 6.995900), category: .hallway, isNavigable: false),

        NavNode(id: "MiddleB", displayNameKey: "node.middleB", block: "B", floor: 0,
                coordinate: GeoCoord(lat: 50.927572, lon: 6.994962), category: .hallway, isNavigable: false),
        NavNode(id: "MiddleC", displayNameKey: "node.middleC", block: "C", floor: 0,
                coordinate: GeoCoord(lat: 50.927209, lon: 6.996021), category: .hallway, isNavigable: false),

        NavNode(id: "SB-B-Sport", displayNameKey: "node.connBSport", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927916, lon: 6.995235), category: .staircase, isNavigable: false),
        NavNode(id: "SB-A-B", displayNameKey: "node.connAB", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927294, lon: 6.994960), category: .staircase, isNavigable: false),
        NavNode(id: "SB-A-C", displayNameKey: "node.connAC", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927056, lon: 6.995652), category: .staircase, isNavigable: false),
        NavNode(id: "SB-C-Aula", displayNameKey: "node.connCAula", block: "", floor: 0,
                // Real always-open WC-SB-C-Aula entrance point supplied by Batu.
                // This is the outdoor/portal position; routes should enter here, not
                // through the parking-side wall.
                coordinate: GeoCoord(lat: 50.92757671724877, lon: 6.99622846367194), category: .staircase, isNavigable: false),

        // Toilets
        NavNode(id: "WC-SB-B-Sport", displayNameKey: "WC (B/Sport)", block: "", floor: 0,
                // Real WC-SB-B-Sport entrance point supplied by Batu. The previous
                // coordinate was too far inside/sideways and made the route cut
                // through the Sport/B wall before reaching the Hof mesh.
                coordinate: GeoCoord(lat: 50.927883635784866, lon: 6.995331984364071), category: .toilet, isNavigable: true),
        NavNode(id: "WC-SB-A-B", displayNameKey: "WC (A/B)", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927261, lon: 6.994931), category: .toilet, isNavigable: true),
        NavNode(id: "WC-SB-A-C", displayNameKey: "WC (A/C)", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927023, lon: 6.995624), category: .toilet, isNavigable: true),
        NavNode(id: "WC-SB-C-Aula", displayNameKey: "WC (C/Aula)", block: "", floor: 0,
                // Same physical WC-SB-C-Aula portal; kept selectable for users.
                coordinate: GeoCoord(lat: 50.92757671724877, lon: 6.99622846367194), category: .toilet, isNavigable: true),

        // Physical outside entry from the parking side into the C/Aula connector.
        // Important: routes from Parkplatz must terminate at a door on the wall first,
        // then continue inside. Connecting Parkplatz directly to WC/SB/Aula made the
        // blue polyline cut through the physical wall in the 12:23 screenshot.
        NavNode(id: "Door-C-Aula", displayNameKey: "node.connCAula", block: "", floor: 0,
                // Alias portal for parking/outdoor approaches. Same real door as
                // WC-SB-C-Aula, using the user-supplied physical entrance point.
                coordinate: GeoCoord(lat: 50.92757671724877, lon: 6.99622846367194), category: .entrance, isNavigable: false),

        // Special areas
        NavNode(id: "Sporthalle", displayNameKey: "node.gym", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.928130, lon: 6.995670), category: .sport, isNavigable: true),
        NavNode(id: "Umkleide", displayNameKey: "node.changingRoom", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.927997, lon: 6.995554), category: .special, isNavigable: true),
        NavNode(id: "Aula", displayNameKey: "node.aula", block: "Aula", floor: 0,
                coordinate: GeoCoord(lat: 50.927722, lon: 6.996407), category: .special, isNavigable: true),
        // Hof: relocated to walkable area NORTH of the central platform (was on the
        // platform itself, which is a forbidden zone — never route through!)
        NavNode(id: "Hof", displayNameKey: "node.courtyard", block: "Hof", floor: 0,
                coordinate: GeoCoord(lat: 50.927790, lon: 6.995600), category: .courtyard, isNavigable: true),

        // ── Named rooms from floor plan (A-block) ──
        NavNode(id: "A001", displayNameKey: "node.a001", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927248, lon: 6.995372), category: .special, isNavigable: true),
        NavNode(id: "A002", displayNameKey: "node.a002", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927217, lon: 6.995463), category: .room, isNavigable: true),
        NavNode(id: "A003", displayNameKey: "node.a003", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927185, lon: 6.995556), category: .special, isNavigable: true),
        NavNode(id: "A007", displayNameKey: "node.a007", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927200, lon: 6.995540), category: .special, isNavigable: true),

        // ── Named rooms from floor plan (E-block, near Sporthalle) ──
        NavNode(id: "E009", displayNameKey: "node.e009", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.927960, lon: 6.995450), category: .room, isNavigable: true),
        NavNode(id: "E010", displayNameKey: "node.e010", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.927975, lon: 6.995360), category: .room, isNavigable: true),

        // ── Named rooms from floor plan (D-block, near Aula) ──
        NavNode(id: "D002", displayNameKey: "node.d002", block: "Aula", floor: 0,
                coordinate: GeoCoord(lat: 50.927593, lon: 6.996465), category: .special, isNavigable: true),

        // Elevator (mentioned in floor plan, lower-left A area)
        NavNode(id: "Aufzug-A", displayNameKey: "node.elevatorA", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927120, lon: 6.995560), category: .elevator, isNavigable: true),

        // Outdoor / approach
        NavNode(id: "Eingang", displayNameKey: "node.entrance", block: "Außen", floor: 0,
                coordinate: GeoCoord(lat: 50.927113, lon: 6.997490), category: .entrance, isNavigable: true),
        NavNode(id: "Haupteingang", displayNameKey: "node.mainEntrance", block: "Außen", floor: 0,
                coordinate: GeoCoord(lat: 50.928622, lon: 6.996593), category: .entrance, isNavigable: true),
        NavNode(id: "Parkplatz", displayNameKey: "node.carParking", block: "Außen", floor: 0,
                coordinate: GeoCoord(lat: 50.927258, lon: 6.996649), category: .parking, isNavigable: true),
        // Fahrradabstellplatz: relocated from polygon CENTER (which forced any line
        // to/from it to cross the bike polygon) to its SW edge, on the side of the
        // walking path between Sport block and bike racks. Verified: lon 6.996170
        // < polygon western lon 6.996154 → just outside the polygon (path side).
        NavNode(id: "Fahrradabstellplatz", displayNameKey: "node.bikeParking", block: "Außen", floor: 0,
                coordinate: GeoCoord(lat: 50.927935, lon: 6.996170), category: .bike, isNavigable: true),


        // ── Door entry nodes (specific access doors at building edges) ──
        // Sporthalle direct: PRIMARY entrance for sports activities (faster than WC-SB-B-Sport)
        NavNode(id: "Door-Sporthalle", displayNameKey: "node.doorSporthalle", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.927828, lon: 6.995774), category: .entrance, isNavigable: true),
        // Mensa EG: direct ground-floor entrance to Forum/Cafeteria from the Hof
        NavNode(id: "Door-Mensa-EG", displayNameKey: "node.doorMensa", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927294, lon: 6.995405), category: .entrance, isNavigable: true),
    ]

    // MARK: - Room display names
    // Internal node IDs stay as B1/B2/... and C1/C2/... so the existing graph/edges keep working.
    // Only the visible room names are changed. For OG rooms, the first 0 in the EG room number becomes 1.
    private static let bRoomDisplayGround: [String: String] = [
        "B1": "B013",
        "B2": "B017",
        "B3": "B011",
        "B4": "B019",
        "B5": "B009",
        "B6": "B021",
        "B7": "B005",
        "B8": "B022/B023/B024",
        "B9": "B003/B004",
        "B10": "B022/B023/B024",
        "B11": "B001",
        "B12": "B025/B026"
    ]

    private static let cRoomDisplayGround: [String: String] = [
        "C1": "C009",
        "C2": "C013",
        "C3": "C007",
        "C4": "C015",
        "C5": "C005",
        "C6": "C017",
        "C7": "C004",
        "C8": "C021",
        "C9": "C002",
        "C10": "C023",
        "C11": "C001",
        "C12": "C025"
    ]

    private static func upperRoomName(from groundName: String) -> String {
        groundName.replacingOccurrences(of: "0", with: "1", options: [], range: groundName.range(of: "0"))
    }

    // MARK: - Upper Floor Nodes (B + C)
    static let upperFloorNodes: [NavNode] = {
        var nodes = [NavNode]()
        // Upper corridor nodes — split N/M/S like ground floor
        nodes.append(NavNode(id: "FlurB-OG-N", displayNameKey: "node.corridorBOG", block: "B", floor: 1,
                             coordinate: GeoCoord(lat: 50.927780, lon: 6.995040), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "FlurB-OG-M", displayNameKey: "node.corridorBOG", block: "B", floor: 1,
                             coordinate: GeoCoord(lat: 50.927576, lon: 6.994962), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "FlurB-OG-S", displayNameKey: "node.corridorBOG", block: "B", floor: 1,
                             coordinate: GeoCoord(lat: 50.927360, lon: 6.994830), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "FlurC-OG-N", displayNameKey: "node.corridorCOG", block: "C", floor: 1,
                             coordinate: GeoCoord(lat: 50.927450, lon: 6.996150), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "FlurC-OG-M", displayNameKey: "node.corridorCOG", block: "C", floor: 1,
                             coordinate: GeoCoord(lat: 50.927214, lon: 6.996030), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "FlurC-OG-S", displayNameKey: "node.corridorCOG", block: "C", floor: 1,
                             coordinate: GeoCoord(lat: 50.927000, lon: 6.995900), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "MiddleB-OG", displayNameKey: "node.middleBOG", block: "B", floor: 1,
                             coordinate: GeoCoord(lat: 50.927572, lon: 6.994962), category: .hallway, isNavigable: false))
        nodes.append(NavNode(id: "MiddleC-OG", displayNameKey: "node.middleCOG", block: "C", floor: 1,
                             coordinate: GeoCoord(lat: 50.927209, lon: 6.996021), category: .hallway, isNavigable: false))

        // B upper floor rooms (same coords as ground floor)
        let bCoords: [(String, Double, Double)] = [
            ("B1", 50.927848, 6.995116), ("B2", 50.927808, 6.995242),
            ("B3", 50.927753, 6.995036), ("B4", 50.927711, 6.995161),
            ("B5", 50.927659, 6.994956), ("B6", 50.927616, 6.995078),
            ("B7", 50.927531, 6.994831), ("B8", 50.927484, 6.994967),
            ("B9", 50.927436, 6.994749), ("B10", 50.927384, 6.994894),
            ("B11", 50.927341, 6.994667), ("B12", 50.927293, 6.994803),
        ]
        for (name, lat, lon) in bCoords {
            nodes.append(NavNode(id: "\(name)-OG", displayNameKey: upperRoomName(from: bRoomDisplayGround[name] ?? name), block: "B", floor: 1,
                                 coordinate: GeoCoord(lat: lat, lon: lon), category: .room, isNavigable: true))
        }

        // C upper floor rooms
        let cCoords: [(String, Double, Double)] = [
            ("C1", 50.927487, 6.996176), ("C2", 50.927443, 6.996303),
            ("C3", 50.927388, 6.996098), ("C4", 50.927347, 6.996219),
            ("C5", 50.927294, 6.996017), ("C6", 50.927250, 6.996145),
            ("C7", 50.927163, 6.995897), ("C8", 50.927117, 6.996030),
            ("C9", 50.927067, 6.995815), ("C10", 50.927023, 6.995949),
            ("C11", 50.926973, 6.995736), ("C12", 50.926928, 6.995866),
        ]
        for (name, lat, lon) in cCoords {
            nodes.append(NavNode(id: "\(name)-OG", displayNameKey: upperRoomName(from: cRoomDisplayGround[name] ?? name), block: "C", floor: 1,
                                 coordinate: GeoCoord(lat: lat, lon: lon), category: .room, isNavigable: true))
        }
        return nodes
    }()

    static let nodes: [NavNode] = groundFloorNodes + upperFloorNodes

    static func node(by id: String) -> NavNode? { nodes.first { $0.id == id } }
    static var selectableNodes: [NavNode] { nodes.filter { $0.isNavigable } }

    // MARK: - Routing
    // Routes are computed on the walkability grid generated from the CAD floor plan
    // (see SchoolGridRouter / Tools/school-grid). Walls, the Hof pit and closed facades are
    // blocked cells there, so a route can never cut through a building.
    static func findRoute(from startID: String, to endID: String) -> [NavStep] {
        guard let startNode = node(by: startID), let endNode = node(by: endID) else {
            return [NavStep(instruction: L.s("nav.roomNotFound"), icon: "xmark.circle", coordinate: nil, pathCoordinates: [], floor: 0)]
        }
        if startID == endID {
            return [NavStep(instruction: L.s("nav.alreadyHere"), icon: "checkmark.circle.fill",
                            coordinate: startNode.coordinate, pathCoordinates: [], floor: startNode.floor)]
        }
        guard let steps = SchoolGridRouter.shared?.route(from: startNode, to: endNode) else {
            return [NavStep(instruction: L.s("nav.noRoute"), icon: "exclamationmark.triangle", coordinate: nil, pathCoordinates: [], floor: 0)]
        }
        return steps
    }
}

// ============================================================
// MARK: - Location Manager
// ============================================================

enum LocateOutcome {
    case success(CLLocationCoordinate2D)
    case permissionDenied
    case timedOut
}

class NavLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?
    @Published var isTracking = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }

    func startTracking() {
        requestPermission()
        manager.startUpdatingLocation()
        isTracking = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        lastLocation = locs.last?.coordinate
    }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authorizationStatus = m.authorizationStatus
    }

    /// Waits for a fresh GPS fix instead of guessing a fixed delay. Discards any
    /// stale `lastLocation` from a previous session first, so an old fix can never
    /// be mistaken for the current position when the new fix arrives late or not at all.
    @MainActor
    func locateOnce(timeout: TimeInterval = 8.0) async -> LocateOutcome {
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            return .permissionDenied
        }

        lastLocation = nil
        startTracking()
        defer { stopTracking() }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                return .permissionDenied
            }
            if let loc = lastLocation {
                return .success(loc)
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return .timedOut
    }

    func closestNode(to coord: CLLocationCoordinate2D, floor: Int? = nil) -> NavNode? {
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let pool: [NavNode] = {
            if let f = floor {
                return SchoolGraph.selectableNodes.filter { $0.floor == f }
            }
            return SchoolGraph.selectableNodes
        }()
        return pool.min(by: {
            CLLocation(latitude: $0.coordinate.lat, longitude: $0.coordinate.lon).distance(from: loc)
            < CLLocation(latitude: $1.coordinate.lat, longitude: $1.coordinate.lon).distance(from: loc)
        })
    }

    func distance(from coord: CLLocationCoordinate2D, to target: GeoCoord) -> Double {
        CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            .distance(from: CLLocation(latitude: target.lat, longitude: target.lon))
    }

    func isOnCampus(_ coord: CLLocationCoordinate2D) -> Bool {
        let center = CLLocation(latitude: SchoolGraph.campusCenter.lat, longitude: SchoolGraph.campusCenter.lon)
        let user = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return user.distance(from: center) <= SchoolGraph.campusRadius
    }
}

// ============================================================
// MARK: - IndoorNavView
// ============================================================

struct IndoorNavView: View {
    @AppStorage("accessibilityMode") private var accessibilityMode = false
    @StateObject private var locationManager = NavLocationManager()

    @State private var startNode: NavNode?
    @State private var endNode: NavNode?
    @State private var showStartPicker = false
    @State private var showEndPicker = false
    @State private var route: [NavStep] = []
    @State private var mapPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: SchoolGraph.campusCenter.coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.0025, longitudeDelta: 0.0025)
    ))

    @State private var isNavigating = false
    @State private var currentStepIndex = 0
    @State private var distanceToNext: Double = 0

    @State private var isDemoMode = false
    @State private var demoTimer: Timer?

    @State private var showOffCampusAlert = false
    @State private var showLocationErrorAlert = false
    @State private var locationErrorMessage = ""
    @State private var directionsExpanded = false
    @State private var selectedFloor = 0

    @State private var showFloorPicker = false
    @State private var pendingGPSCoord: CLLocationCoordinate2D?
    @State private var locating = false

    private let arrivalThreshold: Double = 12.0
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptics = UIImpactFeedbackGenerator(style: .light)
    private let successHaptics = UINotificationFeedbackGenerator()

    private var isActivelyNavigating: Bool { isNavigating || isDemoMode }

    var body: some View {
        ZStack(alignment: .top) {
            mapView
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                if isActivelyNavigating {
                    navigationCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                // Floor toggle pinned to the trailing edge, directly above the bottom panel
                floorToggle
                    .frame(maxWidth: .infinity, alignment: .trailing)

                bottomPanel
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.25), value: isActivelyNavigating)
        .sheet(isPresented: $showStartPicker) {
            NodePickerView(selectedNode: $startNode, title: L.s("nav.selectStart"),
                           accentColor: GSOColors.primary, locationManager: locationManager)
        }
        .sheet(isPresented: $showEndPicker) {
            NodePickerView(selectedNode: $endNode, title: L.s("nav.selectEnd"),
                           accentColor: GSOColors.primary, locationManager: nil)
        }
        .sheet(isPresented: $showFloorPicker) {
            FloorPickerSheet { chosenFloor in
                if let coord = pendingGPSCoord,
                   let closest = locationManager.closestNode(to: coord, floor: chosenFloor) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        startNode = closest
                        selectedFloor = chosenFloor
                    }
                    successHaptics.notificationOccurred(.success)
                }
                pendingGPSCoord = nil
            }
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
        }
        .alert(L.s("nav.offCampusTitle"), isPresented: $showOffCampusAlert) {
            Button("OK") {}
        } message: {
            Text(L.s("nav.offCampusMsg"))
        }
        .alert(L.s("nav.locationErrorTitle"), isPresented: $showLocationErrorAlert) {
            Button("OK") {}
        } message: {
            Text(locationErrorMessage)
        }
        .onChange(of: startNode) { route = []; stopAll() }
        .onChange(of: endNode) { route = []; stopAll() }
        .onChange(of: currentStepIndex) { _, newIdx in
            if newIdx < route.count {
                withAnimation(.easeInOut(duration: 0.3)) { selectedFloor = route[newIdx].floor }
            }
        }
        .onReceive(locationManager.$lastLocation) { loc in
            guard isNavigating, !isDemoMode, let loc = loc else { return }
            updateNavigation(userLocation: loc)
        }
        .onDisappear { stopAll() }
    }

    // MARK: - Navigation Card (turn-by-turn, Apple Maps-style top banner)

    private var navigationCard: some View {
        Group {
            if currentStepIndex < route.count {
                let step = route[currentStepIndex]
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(GSOColors.primary.gradient)
                                .frame(width: 52, height: 52)
                            Image(systemName: step.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.instruction)
                                .font(.title3.weight(.bold))
                                .lineLimit(2)
                                .accessibilityLabel(step.instruction)

                            HStack(spacing: 8) {
                                if !isDemoMode && currentStepIndex < route.count - 1 && distanceToNext > 0 {
                                    Text("\(Int(distanceToNext)) m")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if isDemoMode {
                                    Label(L.s("nav.demoActive"), systemImage: "circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                        .imageScale(.small)
                                }
                                if step.floor > 0 {
                                    Text("OG")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.purple)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.18), in: Capsule())
                                }
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 3) {
                        ForEach(0..<route.count, id: \.self) { i in
                            Capsule()
                                .fill(i <= currentStepIndex ? GSOColors.primary : Color.gray.opacity(0.2))
                                .frame(height: 3)
                        }
                    }

                    HStack {
                        Text("\(L.s("nav.step")) \(currentStepIndex + 1)/\(route.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) { stopAll() } label: {
                            Text(L.s("nav.endNav"))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .padding(14)
                .gsoFloatingCard(radius: GSOMetrics.sheetRadius)
                .accessibilityElement(children: accessibilityMode ? .combine : .contain)
            }
        }
    }

    // MARK: - Floating controls (floor picker + locate-me, Apple Maps-style)

    private var floorToggle: some View {
        VStack(spacing: 0) {
            floorButton(label: L.s("nav.floor.og"), isSelected: selectedFloor == 1, tint: .purple) { selectedFloor = 1 }
            Divider().frame(width: 30)
            floorButton(label: L.s("nav.floor.eg"), isSelected: selectedFloor == 0, tint: GSOColors.primary) { selectedFloor = 0 }
        }
        .gsoFloatingCard(radius: GSOMetrics.controlRadius)
    }

    private func floorButton(label: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptics.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { action() }
        } label: {
            Text(label)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 44, height: 36)
                .background(isSelected ? tint : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $mapPosition) {
            // Outdoor areas (parking, paths, gate) — drawn under buildings
            ForEach(SchoolGraph.outdoorAreas) { area in
                MapPolygon(coordinates: area.corners.map { $0.coordinate })
                    .foregroundStyle(area.fillColor.opacity(area.fillOpacity))
                    .stroke(area.strokeColor.opacity(0.55), lineWidth: 1.2)
            }

            // (forbiddenAreas data is kept internally for routing validation but
            // intentionally NOT rendered on the map — it's a developer-side concept.)

            ForEach(SchoolGraph.buildingOutlines) { outline in
                MapPolygon(coordinates: outline.corners.map { $0.coordinate })
                    .foregroundStyle(outline.color.opacity(0.25))
                    .stroke(outline.color.opacity(0.6), lineWidth: 2)
            }

            ForEach(SchoolGraph.selectableNodes.filter { $0.floor == selectedFloor }) { node in
                if node.category != .hallway {
                    Annotation(node.id, coordinate: node.coordinate.coordinate) {
                        roomMarker(node)
                    }
                }
            }

            if SchoolGraph.showDebugNodesOnMap {
                MapPolyline(coordinates: SchoolGraph.physicalWallLine.map { $0.coordinate })
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 4]))

                ForEach(SchoolGraph.nodes) { node in
                    Annotation(node.id, coordinate: node.coordinate.coordinate) {
                        Circle()
                            .fill(Color.yellow.opacity(0.85))
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 0.7))
                    }
                }
            }

            if route.count >= 2 {
                let startIdx = (isNavigating || isDemoMode) ? currentStepIndex : 0
                let coords = buildPolylineCoords(from: startIdx)
                if coords.count >= 2 {
                    MapPolyline(coordinates: coords)
                        .stroke(GSOColors.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }

            if let start = startNode {
                Annotation("Start", coordinate: start.coordinate.coordinate) {
                    ZStack {
                        Circle().fill(Color.green).frame(width: 26, height: 26)
                        Image(systemName: "location.fill").font(.system(size: 12)).foregroundColor(.white)
                    }
                }
            }
            if let end = endNode {
                Annotation(L.s("nav.selectEnd"), coordinate: end.coordinate.coordinate) {
                    ZStack {
                        Circle().fill(Color.red).frame(width: 26, height: 26)
                        Image(systemName: "flag.fill").font(.system(size: 12)).foregroundColor(.white)
                    }
                }
            }

            // User blue dot (live)
            if isNavigating && !isDemoMode, let loc = locationManager.lastLocation {
                Annotation("", coordinate: loc) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.15)).frame(width: 40, height: 40)
                        Circle().fill(Color.blue).frame(width: 14, height: 14)
                        Circle().stroke(Color.white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
            }

            // Demo dot — positioned at START of current step (not destination)
            if isDemoMode, currentStepIndex < route.count {
                let step = route[currentStepIndex]
                if let coord = step.pathCoordinates.first ?? step.coordinate {
                    Annotation("", coordinate: coord.coordinate) {
                        ZStack {
                            Circle().fill(Color.orange.opacity(0.15)).frame(width: 40, height: 40)
                            Circle().fill(Color.orange).frame(width: 14, height: 14)
                            Circle().stroke(Color.white, lineWidth: 2).frame(width: 14, height: 14)
                        }
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .accessibilityHidden(accessibilityMode)
    }

    private func buildPolylineCoords(from startIndex: Int) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D]()
        for i in startIndex..<route.count {
            let step = route[i]
            if step.pathCoordinates.isEmpty {
                if let c = step.coordinate,
                   coords.last?.latitude != c.lat || coords.last?.longitude != c.lon {
                    coords.append(c.coordinate)
                }
            } else {
                for gc in step.pathCoordinates {
                    if coords.last?.latitude != gc.lat || coords.last?.longitude != gc.lon {
                        coords.append(gc.coordinate)
                    }
                }
            }
        }
        return coords
    }

    // MARK: - Bottom Panel (inline card, always visible above the tab bar)

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            if isActivelyNavigating {
                navActiveBar
            } else {
                searchFields
                if !route.isEmpty {
                    routeSummaryCard
                }
            }
        }
        .padding(14)
        .gsoFloatingCard(radius: GSOMetrics.sheetRadius)
    }

    private var navActiveBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(endNode?.displayName ?? "")
                    .font(.headline)
                    .lineLimit(1)
                if !isDemoMode && distanceToNext > 0 {
                    Text("\(Int(distanceToNext)) m \(L.s("nav.toNextPoint"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) { stopAll() } label: {
                Text(L.s("nav.endNav"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.red, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var searchFields: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                searchField(icon: "location.circle.fill", iconColor: .green,
                            text: startNode?.displayName ?? L.s("nav.whereAreYou"),
                            isPlaceholder: startNode == nil) { showStartPicker = true }

                Button { locateUser() } label: {
                    ZStack {
                        if locating {
                            ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.6)
                        } else {
                            Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: GSOMetrics.pillRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(locating)
            }

            HStack(spacing: 8) {
                searchField(icon: "flag.circle.fill", iconColor: .red,
                            text: endNode?.displayName ?? L.s("nav.whereToGo"),
                            isPlaceholder: endNode == nil) { showEndPicker = true }

                Button {
                    lightHaptics.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        let tmp = startNode; startNode = endNode; endNode = tmp
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(GSOColors.primary, in: RoundedRectangle(cornerRadius: GSOMetrics.pillRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if startNode != nil && endNode != nil && route.isEmpty {
                Button {
                    haptics.impactOccurred()
                    if let s = startNode, let e = endNode {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            route = SchoolGraph.findRoute(from: s.id, to: e.id)
                        }
                        directionsExpanded = false
                    }
                } label: {
                    Label(L.s("nav.calculate"), systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(GSOColors.primary, in: RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func searchField(icon: String, iconColor: Color, text: String, isPlaceholder: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(iconColor).font(.system(size: 16))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Route Summary Card (Apple Maps-style)

    private var routeSummaryCard: some View {
        let stepsCount = max(0, route.count - 2)
        let totalDistance = estimatedDistance()
        let totalMinutes = max(1, Int(totalDistance / 60))

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(totalMinutes)").font(.title2.weight(.bold))
                        Text(L.s("nav.approxMin")).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(Int(totalDistance)) m · \(stepsCount) \(L.s("nav.steps"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 4) {
                    routeEndpoint(color: .green, icon: "location.fill", label: startNode?.displayName ?? "")
                    routeEndpoint(color: .red, icon: "flag.fill", label: endNode?.displayName ?? "")
                }

                Button {
                    lightHaptics.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        route = []
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                lightHaptics.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    directionsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: directionsExpanded ? "chevron.up" : "list.bullet")
                    Text(directionsExpanded ? L.s("nav.hideSteps") : L.s("nav.showSteps"))
                    Spacer()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 10)
            }
            .buttonStyle(.plain)

            if directionsExpanded {
                stepsList
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }

            HStack(spacing: 8) {
                Button { startNavigation() } label: {
                    Label(L.s("nav.startNav"), systemImage: "location.north.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(GSOColors.primary.gradient, in: RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())

                Button { startDemo() } label: {
                    Label(L.s("nav.startDemo"), systemImage: "play.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: GSOMetrics.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
    }

    private var stepsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(route.enumerated()), id: \.element.id) { idx, step in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(idx == 0 || idx == route.count - 1 ? Color.green : GSOColors.primary)
                                    .frame(width: 18, height: 18)
                                Image(systemName: step.icon)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white)
                            }
                            if idx < route.count - 1 {
                                Rectangle()
                                    .fill(GSOColors.primary.opacity(0.2))
                                    .frame(width: 2, height: 12)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.instruction).font(.caption)
                            if step.floor > 0 {
                                Text("OG").font(.caption2.weight(.bold)).foregroundStyle(.purple.opacity(0.7))
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(step.instruction)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 160)
    }

    private func routeEndpoint(color: Color, icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(color).frame(width: 14, height: 14)
                Image(systemName: icon)
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private func estimatedDistance() -> Double {
        var total: Double = 0
        for step in route {
            let coords = step.pathCoordinates
            for i in 1..<max(coords.count, 1) {
                guard i < coords.count else { break }
                let a = CLLocation(latitude: coords[i-1].lat, longitude: coords[i-1].lon)
                let b = CLLocation(latitude: coords[i].lat,   longitude: coords[i].lon)
                total += a.distance(from: b)
            }
        }
        return max(total, 1)
    }

    // MARK: - Actions

    private func locateUser() {
        lightHaptics.impactOccurred()
        locating = true
        Task {
            let outcome = await locationManager.locateOnce()
            locating = false
            switch outcome {
            case .success(let coord):
                if locationManager.isOnCampus(coord) {
                    pendingGPSCoord = coord
                    showFloorPicker = true
                } else {
                    successHaptics.notificationOccurred(.warning)
                    showOffCampusAlert = true
                }
            case .permissionDenied:
                successHaptics.notificationOccurred(.warning)
                locationErrorMessage = L.s("nav.locationDenied")
                showLocationErrorAlert = true
            case .timedOut:
                successHaptics.notificationOccurred(.warning)
                locationErrorMessage = L.s("nav.locationTimeout")
                showLocationErrorAlert = true
            }
        }
    }

    private func startNavigation() {
        guard !route.isEmpty else { return }
        haptics.impactOccurred()
        successHaptics.notificationOccurred(.success)
        currentStepIndex = 0
        isNavigating = true
        isDemoMode = false
        locationManager.startTracking()
        zoomToStep(0)

        if accessibilityMode {
            UIAccessibility.post(notification: .announcement, argument: route[0].instruction)
        }
    }

    private func startDemo() {
        guard !route.isEmpty else { return }
        haptics.impactOccurred()
        currentStepIndex = 0
        isDemoMode = true
        isNavigating = false

        // Initial zoom to start
        zoomToStepSmooth(0)

        demoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            if currentStepIndex < route.count - 1 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    currentStepIndex += 1
                }

                // Zoom in to new step
                if let coord = route[currentStepIndex].pathCoordinates.first ?? route[currentStepIndex].coordinate {
                    withAnimation(.easeInOut(duration: 1.2)) {
                        mapPosition = .region(MKCoordinateRegion(
                            center: coord.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.0008, longitudeDelta: 0.0008)))
                    }
                    // Ease back out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            mapPosition = .region(MKCoordinateRegion(
                                center: coord.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.0018, longitudeDelta: 0.0018)))
                        }
                    }
                }

                if accessibilityMode {
                    UIAccessibility.post(notification: .announcement, argument: route[currentStepIndex].instruction)
                }
            } else {
                demoTimer?.invalidate()
                demoTimer = nil
            }
        }
    }

    private func stopAll() {
        isNavigating = false
        isDemoMode = false
        currentStepIndex = 0
        locationManager.stopTracking()
        demoTimer?.invalidate()
        demoTimer = nil
        directionsExpanded = false
        withAnimation {
            mapPosition = .region(MKCoordinateRegion(
                center: SchoolGraph.campusCenter.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0025, longitudeDelta: 0.0025)))
        }
    }

    private func zoomToStep(_ idx: Int) {
        guard idx < route.count, let coord = route[idx].coordinate else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            mapPosition = .region(MKCoordinateRegion(
                center: coord.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)))
        }
    }

    private func zoomToStepSmooth(_ idx: Int) {
        guard idx < route.count else { return }
        let coord = route[idx].pathCoordinates.first ?? route[idx].coordinate
        guard let c = coord else { return }
        withAnimation(.easeInOut(duration: 1.0)) {
            mapPosition = .region(MKCoordinateRegion(
                center: c.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0012, longitudeDelta: 0.0012)))
        }
    }

    private func updateNavigation(userLocation: CLLocationCoordinate2D) {
        withAnimation(.easeOut(duration: 0.5)) {
            mapPosition = .region(MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)))
        }
        let nextIdx = min(currentStepIndex + 1, route.count - 1)
        guard let target = route[nextIdx].coordinate else { return }
        let dist = locationManager.distance(from: userLocation, to: target)
        distanceToNext = dist
        if dist < arrivalThreshold && currentStepIndex < route.count - 1 {
            withAnimation { currentStepIndex += 1 }
            if accessibilityMode {
                UIAccessibility.post(notification: .announcement, argument: route[currentStepIndex].instruction)
            }
        }
    }

    // MARK: - Markers
    @ViewBuilder
    private func roomMarker(_ node: NavNode) -> some View {
        let isSelected = node.id == startNode?.id || node.id == endNode?.id
        if !isSelected {
            VStack(spacing: 1) {
                Circle()
                    .fill(colorForCategory(node.category))
                    .frame(width: node.floor > 0 ? 8 : 10, height: node.floor > 0 ? 8 : 10)
                    .overlay(Circle().stroke(.white, lineWidth: 1))
                    .overlay(
                        node.floor > 0
                        ? Circle().stroke(Color.purple, lineWidth: 1.5)
                        : nil
                    )
                Text(node.displayName)
                    .font(.system(size: node.displayName.contains("/") ? 5.5 : 7, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
    }

    private func colorForCategory(_ cat: NavNode.NodeCategory) -> Color {
        switch cat {
        case .room: return .blue; case .staircase: return .purple; case .elevator: return .purple
        case .hallway: return .gray; case .toilet: return .teal; case .entrance: return .green
        case .courtyard: return .mint; case .sport: return .pink; case .special: return .orange
        case .food: return .yellow; case .parking: return Color(white: 0.45); case .bike: return .blue
        }
    }
}

// ============================================================
// MARK: - Node Picker
// ============================================================

struct NodePickerView: View {
    @Binding var selectedNode: NavNode?
    let title: String
    let accentColor: Color
    var locationManager: NavLocationManager?
    @State private var search = ""
    @State private var locating = false
    @State private var showOffCampusAlert = false
    @State private var showLocationErrorAlert = false
    @State private var locationErrorMessage = ""
    @State private var showFloorPicker = false
    @State private var pendingGPSCoord: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    private var filtered: [NavNode] {
        let s = SchoolGraph.selectableNodes
        guard !search.isEmpty else { return s }
        return s.filter {
            $0.displayName.localizedCaseInsensitiveContains(search) ||
            $0.id.localizedCaseInsensitiveContains(search) ||
            $0.block.localizedCaseInsensitiveContains(search)
        }
    }

    private var grouped: [(String, [NavNode])] {
        Dictionary(grouping: filtered) { n -> String in
            let floorLabel = n.floor > 0 ? " (OG)" : ""
            if n.block.isEmpty { return L.s("nav.floor") }
            if n.block == "Hof" { return L.s("node.courtyard") }
            if n.block == "Aula" { return L.s("node.aula") }
            if n.block == "Sport" { return L.s("node.gym") }
            if n.block == "Außen" { return L.s("nav.outdoor") }
            return "Block \(n.block)\(floorLabel)"
        }.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                if locationManager != nil {
                    Section {
                        Button {
                            guard let locationManager else { return }
                            locating = true
                            Task {
                                let outcome = await locationManager.locateOnce()
                                locating = false
                                switch outcome {
                                case .success(let coord):
                                    if locationManager.isOnCampus(coord) {
                                        pendingGPSCoord = coord
                                        showFloorPicker = true
                                    } else {
                                        showOffCampusAlert = true
                                    }
                                case .permissionDenied:
                                    locationErrorMessage = L.s("nav.locationDenied")
                                    showLocationErrorAlert = true
                                case .timedOut:
                                    locationErrorMessage = L.s("nav.locationTimeout")
                                    showLocationErrorAlert = true
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.green.opacity(0.15)).frame(width: 32, height: 32)
                                    Image(systemName: "location.fill").foregroundStyle(.green).font(.system(size: 14, weight: .medium))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L.s("nav.currentLocation")).font(.subheadline.weight(.semibold))
                                    Text(L.s("nav.gpsHint")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if locating { ProgressView() }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                ForEach(grouped, id: \.0) { section, nodes in
                    Section(header: Text(section)) {
                        ForEach(nodes) { node in
                            Button {
                                selectedNode = node; dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(accentColor.opacity(0.15)).frame(width: 32, height: 32)
                                        Image(systemName: iconFor(node.category))
                                            .foregroundStyle(accentColor).font(.system(size: 14, weight: .medium))
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(node.id).font(.subheadline.weight(.semibold))
                                        if node.displayName != node.id {
                                            Text(node.displayName).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if node.floor > 0 {
                                        Text("OG").font(.caption2.weight(.bold))
                                            .foregroundStyle(.purple)
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.1), in: Capsule())
                                    }
                                    if selectedNode?.id == node.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: L.s("nav.searchRoom"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.s("settings.done")) { dismiss() }
                }
            }
            .alert(L.s("nav.offCampusTitle"), isPresented: $showOffCampusAlert) {
                Button("OK") {}
            } message: {
                Text(L.s("nav.offCampusMsg"))
            }
            .alert(L.s("nav.locationErrorTitle"), isPresented: $showLocationErrorAlert) {
                Button("OK") {}
            } message: {
                Text(locationErrorMessage)
            }
            .sheet(isPresented: $showFloorPicker) {
                FloorPickerSheet { chosenFloor in
                    if let coord = pendingGPSCoord,
                       let closest = locationManager?.closestNode(to: coord, floor: chosenFloor) {
                        selectedNode = closest
                        dismiss()
                    }
                    pendingGPSCoord = nil
                }
                .presentationDetents([.height(320), .medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func iconFor(_ cat: NavNode.NodeCategory) -> String {
        switch cat {
        case .room: return "door.left.hand.open"; case .staircase: return "stairs"
        case .elevator: return "arrow.up.arrow.down"; case .hallway: return "arrow.left.and.right"
        case .toilet: return "figure.dress.line.vertical.figure"; case .entrance: return "door.garage.open"
        case .courtyard: return "tree"; case .sport: return "sportscourt"
        case .special: return "star"; case .food: return "fork.knife"
        case .parking: return "car.fill"; case .bike: return "bicycle"
        }
    }
}

// ============================================================
// MARK: - Floor Picker Sheet (GPS)
// ============================================================

struct FloorPickerSheet: View {
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(GSOColors.primary)
                    .padding(.top, 6)
                Text(L.s("nav.floorQuestionTitle"))
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(L.s("nav.floorQuestionMsg"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                floorButton(floor: 0, label: L.s("nav.floor.ground"),
                            icon: "arrow.down.to.line.compact",
                            color: GSOColors.primary)
                floorButton(floor: 1, label: L.s("nav.floor.upper"),
                            icon: "arrow.up.to.line.compact",
                            color: .purple)
            }
            .padding(.horizontal, 20)

            Button {
                dismiss()
            } label: {
                Text(L.s("settings.done"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity)
    }

    private func floorButton(floor: Int, label: String, icon: String, color: Color) -> some View {
        Button {
            haptics.impactOccurred()
            onSelect(floor)
            dismiss()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [color, color.opacity(0.78)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(floor == 0 ? L.s("nav.floor.eg") : L.s("nav.floor.og"))
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// ============================================================
// MARK: - Pressable Button Style (Apple-Style)
// ============================================================

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
