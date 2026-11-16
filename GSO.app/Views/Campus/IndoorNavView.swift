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

struct NavEdge {
    let from: String
    let to: String
    let weight: Double
    let instruction: String
    let reverseInstruction: String
    let icon: String
    let reverseIcon: String
    let waypoints: [GeoCoord]
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

    // Developer diagnostics. Keep false for production; set true while fixing routes.
    // It validates only outdoor/helper edges against building outlines and all edges
    // against forbidden zones, then prints exact problem edges in the Xcode console.
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
    // This is NOT rendered in production; it is used by the debug validator to
    // catch route segments that cross real school walls even when the rough
    // colored building polygons are not precise enough.
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


    // MARK: - Helper for edge creation
    private static func re(_ room: String, _ corr: String, _ w: Double, _ iKey: String) -> NavEdge {
        NavEdge(from: room, to: corr, weight: w,
                instruction: iKey, reverseInstruction: "nav.goToRoom",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open", waypoints: [])
    }

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
                coordinate: GeoCoord(lat: 50.927691, lon: 6.996388), category: .special, isNavigable: true),
        // Hof: relocated to walkable area NORTH of the central platform (was on the
        // platform itself, which is a forbidden zone — never route through!)
        NavNode(id: "Hof", displayNameKey: "node.courtyard", block: "Hof", floor: 0,
                coordinate: GeoCoord(lat: 50.927790, lon: 6.995600), category: .courtyard, isNavigable: true),

        // ── Named rooms from floor plan (A-block) ──
        NavNode(id: "A001", displayNameKey: "node.a001", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927245, lon: 6.995460), category: .special, isNavigable: true),
        NavNode(id: "A002", displayNameKey: "node.a002", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927290, lon: 6.995380), category: .room, isNavigable: true),
        NavNode(id: "A003", displayNameKey: "node.a003", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927140, lon: 6.995410), category: .special, isNavigable: true),
        NavNode(id: "A007", displayNameKey: "node.a007", block: "A", floor: 0,
                coordinate: GeoCoord(lat: 50.927200, lon: 6.995540), category: .special, isNavigable: true),

        // ── Named rooms from floor plan (E-block, near Sporthalle) ──
        NavNode(id: "E009", displayNameKey: "node.e009", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.927960, lon: 6.995450), category: .room, isNavigable: true),
        NavNode(id: "E010", displayNameKey: "node.e010", block: "Sport", floor: 0,
                coordinate: GeoCoord(lat: 50.927975, lon: 6.995360), category: .room, isNavigable: true),

        // ── Named rooms from floor plan (D-block, near Aula) ──
        NavNode(id: "D002", displayNameKey: "node.d002", block: "Aula", floor: 0,
                coordinate: GeoCoord(lat: 50.927790, lon: 6.996440), category: .special, isNavigable: true),

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


        // ── Hof ring mesh: 8 invisible waypoints AROUND the central platform ──
        // Routes through Hof must follow this ring; never cross the platform.
        NavNode(id: "HM-N",  displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927790, lon: 6.995600), category: .hallway, isNavigable: false),
        NavNode(id: "HM-NE", displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927750, lon: 6.996050), category: .hallway, isNavigable: false),
        NavNode(id: "HM-E",  displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927580, lon: 6.996150), category: .hallway, isNavigable: false),
        NavNode(id: "HM-SE", displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927400, lon: 6.995960), category: .hallway, isNavigable: false),
        NavNode(id: "HM-S",  displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927240, lon: 6.995680), category: .hallway, isNavigable: false),
        NavNode(id: "HM-SW", displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927280, lon: 6.995420), category: .hallway, isNavigable: false),
        NavNode(id: "HM-W",  displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927450, lon: 6.995160), category: .hallway, isNavigable: false),
        NavNode(id: "HM-NW", displayNameKey: "node.hofMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927660, lon: 6.995300), category: .hallway, isNavigable: false),

        // ── Outdoor mesh: bike-parking → school grounds ──
        // Placed in the ~10m walkable strip BETWEEN Sport east edge (max lon 6.996039)
        // and bike polygon west edge (min lon 6.996154). All three lons sit at 6.996070–
        // 6.996100 which is outside both buildings; verified analytically.
        NavNode(id: "BSP-1", displayNameKey: "node.outdoorMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.92794294492086, lon: 6.996016215167316), category: .hallway, isNavigable: false),
        NavNode(id: "BSP-2", displayNameKey: "node.outdoorMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927850, lon: 6.995900), category: .hallway, isNavigable: false),
        NavNode(id: "BSP-3", displayNameKey: "node.outdoorMesh", block: "", floor: 0,
                coordinate: GeoCoord(lat: 50.927753499384124, lon: 6.995743375749953), category: .hallway, isNavigable: false),


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

    // MARK: - Corridor waypoint helpers
    // B corridor centerline points (NW to SE)
    private static let bCorridorNorth = GeoCoord(lat: 50.927850, lon: 6.995080)
    private static let bCorridorMidN  = GeoCoord(lat: 50.927720, lon: 6.995010)
    private static let bCorridorMid   = GeoCoord(lat: 50.927576, lon: 6.994962)
    private static let bCorridorMidS  = GeoCoord(lat: 50.927450, lon: 6.994880)
    private static let bCorridorSouth = GeoCoord(lat: 50.927320, lon: 6.994800)

    // C corridor centerline points (NW to SE)
    private static let cCorridorNorth = GeoCoord(lat: 50.927470, lon: 6.996160)
    private static let cCorridorMidN  = GeoCoord(lat: 50.927350, lon: 6.996090)
    private static let cCorridorMid   = GeoCoord(lat: 50.927214, lon: 6.996030)
    private static let cCorridorMidS  = GeoCoord(lat: 50.927100, lon: 6.995930)
    private static let cCorridorSouth = GeoCoord(lat: 50.926970, lon: 6.995810)

    // MARK: - Ground Floor Edges
    static let groundFloorEdges: [NavEdge] = [
        // B rooms → nearest corridor segment
        // North rooms (B1-B4) connect to FlurB-N
        re("B1",  "FlurB-N", 4, "nav.goToCorridorB"), re("B2",  "FlurB-N", 4, "nav.goToCorridorB"),
        re("B3",  "FlurB-N", 6, "nav.goToCorridorB"), re("B4",  "FlurB-N", 6, "nav.goToCorridorB"),
        // Mid rooms (B5-B6) connect to FlurB-M
        re("B5",  "FlurB-M", 5, "nav.goToCorridorB"), re("B6",  "FlurB-M", 5, "nav.goToCorridorB"),
        // Mid-stair rooms (B7-B8) use MiddleB
        re("B7",  "MiddleB", 5, "nav.goToMiddleB"),    re("B8",  "MiddleB", 5, "nav.goToMiddleB"),
        // South rooms (B9-B12) connect to FlurB-S
        re("B9",  "FlurB-S", 6, "nav.goToCorridorB"), re("B10", "FlurB-S", 6, "nav.goToCorridorB"),
        re("B11", "FlurB-S", 4, "nav.goToCorridorB"), re("B12", "FlurB-S", 4, "nav.goToCorridorB"),

        // Corridor segment chain
        NavEdge(from: "FlurB-N", to: "FlurB-M", weight: 12,
                instruction: "nav.continueCorridorB", reverseInstruction: "nav.continueCorridorB",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "FlurB-M", to: "FlurB-S", weight: 12,
                instruction: "nav.continueCorridorB", reverseInstruction: "nav.continueCorridorB",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "FlurB-M", to: "MiddleB", weight: 3,
                instruction: "nav.goToMiddleB", reverseInstruction: "nav.goToCorridorB",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),

        // C rooms → nearest corridor segment
        re("C1",  "FlurC-N", 4, "nav.goToCorridorC"), re("C2",  "FlurC-N", 4, "nav.goToCorridorC"),
        re("C3",  "FlurC-N", 6, "nav.goToCorridorC"), re("C4",  "FlurC-N", 6, "nav.goToCorridorC"),
        re("C5",  "FlurC-M", 5, "nav.goToCorridorC"), re("C6",  "FlurC-M", 5, "nav.goToCorridorC"),
        re("C7",  "MiddleC", 5, "nav.goToMiddleC"),    re("C8",  "MiddleC", 5, "nav.goToMiddleC"),
        re("C9",  "FlurC-S", 6, "nav.goToCorridorC"), re("C10", "FlurC-S", 6, "nav.goToCorridorC"),
        re("C11", "FlurC-S", 4, "nav.goToCorridorC"), re("C12", "FlurC-S", 4, "nav.goToCorridorC"),

        NavEdge(from: "FlurC-N", to: "FlurC-M", weight: 12,
                instruction: "nav.continueCorridorC", reverseInstruction: "nav.continueCorridorC",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "FlurC-M", to: "FlurC-S", weight: 12,
                instruction: "nav.continueCorridorC", reverseInstruction: "nav.continueCorridorC",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "FlurC-M", to: "MiddleC", weight: 3,
                instruction: "nav.goToMiddleC", reverseInstruction: "nav.goToCorridorC",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),

        // Building connections — stairs are at corridor ends, so connect to N/S segments
        NavEdge(from: "FlurB-N", to: "SB-B-Sport", weight: 5,
                instruction: "nav.goToStairsBSport", reverseInstruction: "nav.enterCorridorB",
                icon: "arrow.up", reverseIcon: "arrow.down",
                waypoints: [bCorridorNorth]),

        NavEdge(from: "SB-B-Sport", to: "Umkleide", weight: 28,
                instruction: "nav.goToChangingRoom", reverseInstruction: "nav.goToConnBSport",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "Umkleide", to: "Sporthalle", weight: 10,
                instruction: "nav.enterGym", reverseInstruction: "nav.leaveGym",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open", waypoints: []),
        NavEdge(from: "SB-B-Sport", to: "WC-SB-B-Sport", weight: 3,
                instruction: "nav.wcRight", reverseInstruction: "nav.goToConnBSport",
                icon: "figure.dress.line.vertical.figure", reverseIcon: "arrow.left", waypoints: []),

        NavEdge(from: "FlurB-S", to: "SB-A-B", weight: 5,
                instruction: "nav.goToStairsAB", reverseInstruction: "nav.enterCorridorB",
                icon: "arrow.down", reverseIcon: "arrow.up",
                waypoints: [bCorridorSouth]),

        NavEdge(from: "SB-A-B", to: "A-Forum", weight: 8,
                instruction: "nav.goToForum", reverseInstruction: "nav.goToConnAB",
                icon: "arrow.left", reverseIcon: "arrow.right", waypoints: []),
        NavEdge(from: "SB-A-B", to: "WC-SB-A-B", weight: 3,
                instruction: "nav.wcLeft", reverseInstruction: "nav.goToConnAB",
                icon: "figure.dress.line.vertical.figure", reverseIcon: "arrow.right", waypoints: []),

        NavEdge(from: "A-Forum", to: "A-Kiosk", weight: 10,
                instruction: "nav.goToKiosk", reverseInstruction: "nav.goToForum",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "A-Forum", to: "SB-A-C", weight: 15,
                instruction: "nav.goToStairsAC", reverseInstruction: "nav.goToForum",
                icon: "arrow.right", reverseIcon: "arrow.left",
                waypoints: [GeoCoord(lat: 50.927150, lon: 6.995430), GeoCoord(lat: 50.927100, lon: 6.995540)]),

        NavEdge(from: "SB-A-C", to: "FlurC-S", weight: 5,
                instruction: "nav.enterCorridorC", reverseInstruction: "nav.goToConnAC",
                icon: "arrow.right", reverseIcon: "arrow.left",
                waypoints: [cCorridorSouth]),
        NavEdge(from: "SB-A-C", to: "WC-SB-A-C", weight: 3,
                instruction: "nav.wcRight", reverseInstruction: "nav.goToConnAC",
                icon: "figure.dress.line.vertical.figure", reverseIcon: "arrow.left", waypoints: []),

        NavEdge(from: "FlurC-N", to: "SB-C-Aula", weight: 5,
                instruction: "nav.goToStairsCAula", reverseInstruction: "nav.enterCorridorC",
                icon: "arrow.up", reverseIcon: "arrow.down",
                waypoints: [cCorridorNorth]),

        NavEdge(from: "SB-C-Aula", to: "Aula", weight: 10,
                instruction: "nav.enterAula", reverseInstruction: "nav.leaveAula",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open", waypoints: []),
        NavEdge(from: "SB-C-Aula", to: "WC-SB-C-Aula", weight: 3,
                instruction: "nav.wcLeft", reverseInstruction: "nav.goToConnCAula",
                icon: "figure.dress.line.vertical.figure", reverseIcon: "arrow.right", waypoints: []),

        // Courtyard access now goes through the HM-* courtyard ring only.
        // Removed old direct Hof→building edges because they could cut across
        // the forbidden central Hof platform or through building polygons.

        // Kiosk
        NavEdge(from: "A-Kiosk", to: "SB-A-B", weight: 18,
                instruction: "nav.goToStairsAB", reverseInstruction: "nav.goToKiosk",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "A-Kiosk", to: "SB-A-C", weight: 18,
                instruction: "nav.goToStairsAC", reverseInstruction: "nav.goToKiosk",
                icon: "arrow.left", reverseIcon: "arrow.right", waypoints: []),

        // Upper floor A (existing)
        NavEdge(from: "SB-A-B", to: "A-Exam", weight: 15,
                instruction: "nav.stairsUpExam", reverseInstruction: "nav.stairsDownAB",
                icon: "stairs", reverseIcon: "stairs", waypoints: []),
        NavEdge(from: "SB-A-C", to: "A-Exam", weight: 15,
                instruction: "nav.stairsUpExam", reverseInstruction: "nav.stairsDownAC",
                icon: "stairs", reverseIcon: "stairs", waypoints: []),

        // ── Outdoor approach: Eingang ↔ Parkplatz (along marked road)
        NavEdge(from: "Eingang", to: "Parkplatz", weight: 32,
                instruction: "nav.toParking", reverseInstruction: "nav.toEntrance",
                icon: "car.fill", reverseIcon: "door.left.hand.open",
                waypoints: [
                    GeoCoord(lat: 50.927108, lon: 6.997100),
                    GeoCoord(lat: 50.927202, lon: 6.996812),
                ]),

        // Inside connector after entering through the C/Aula door.
        NavEdge(from: "Door-C-Aula", to: "WC-SB-C-Aula", weight: 2,
                instruction: "nav.wcLeft", reverseInstruction: "nav.goToConnCAula",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open",
                waypoints: []),
        NavEdge(from: "Door-C-Aula", to: "SB-C-Aula", weight: 3,
                instruction: "nav.goToStairsCAula", reverseInstruction: "nav.goToConnCAula",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open",
                waypoints: []),

        // Parking can also reach the courtyard ring without crossing the C/Aula block.
        // This is used for routes from the parking side toward A/B/Hof without first
        // going through Fahrradabstellplatz.
        NavEdge(from: "Parkplatz", to: "HM-SE", weight: 95,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.toParking",
                icon: "figure.walk", reverseIcon: "car.fill",
                waypoints: [
                    GeoCoord(lat: 50.927300, lon: 6.996520),
                    GeoCoord(lat: 50.927355, lon: 6.996300),
                    GeoCoord(lat: 50.927390, lon: 6.996080),
                ]),

        // ── Outdoor approach: Eingang ↔ Fahrradabstellplatz (foot path)
        // Final waypoint added at (50.927780, 6.996500) — just south of the bike
        // polygon S-corner (50.927807, 6.996548) — so the polyline routes AROUND
        // the south side of the bike rack instead of crashing through it.
        NavEdge(from: "Eingang", to: "Fahrradabstellplatz", weight: 42,
                instruction: "nav.toBikeParking", reverseInstruction: "nav.toEntrance",
                icon: "bicycle", reverseIcon: "door.left.hand.open",
                waypoints: [
                    GeoCoord(lat: 50.927232, lon: 6.997440),
                    GeoCoord(lat: 50.927708, lon: 6.997286),
                    GeoCoord(lat: 50.927877, lon: 6.996871),
                    GeoCoord(lat: 50.927780, lon: 6.996500),
                ]),

        // (Removed: direct Fahrradabstellplatz → SB-B-Sport edge — its straight-line
        // polyline cut through the Sporthalle building. Replaced below with a mesh
        // path that goes south of the Sport block and through Door-Sporthalle.)

        // ── Main pedestrian entrance (most arrive here on foot/bike)
        // Final waypoint (50.928030, 6.996100) added — sits in the walkable strip
        // WEST of the bike polygon (lon 6.996100 < bike west lon 6.996154), so the
        // polyline reaches Fahrradabstellplatz without cutting through the bikes.
        NavEdge(from: "Haupteingang", to: "Fahrradabstellplatz", weight: 35,
                instruction: "nav.toBikeParking", reverseInstruction: "nav.toMainEntrance",
                icon: "bicycle", reverseIcon: "door.garage.open",
                waypoints: [
                    GeoCoord(lat: 50.928490, lon: 6.996480),
                    GeoCoord(lat: 50.928200, lon: 6.996420),
                    GeoCoord(lat: 50.928030, lon: 6.996100),
                ]),

        // ── Hof ring mesh (chain — adjacent only, never crosses platform!) ──
        NavEdge(from: "HM-N",  to: "HM-NE", weight: 6,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "HM-NE", to: "HM-E",  weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.down", reverseIcon: "arrow.up",
                waypoints: [GeoCoord(lat: 50.927675, lon: 6.996100)]),
        NavEdge(from: "HM-E",  to: "HM-SE", weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "HM-SE", to: "HM-S",  weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.left", reverseIcon: "arrow.right", waypoints: []),
        NavEdge(from: "HM-S",  to: "HM-SW", weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.left", reverseIcon: "arrow.right", waypoints: []),
        NavEdge(from: "HM-SW", to: "HM-W",  weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.up", reverseIcon: "arrow.down", waypoints: []),
        NavEdge(from: "HM-W",  to: "HM-NW", weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.up", reverseIcon: "arrow.down", waypoints: []),
        NavEdge(from: "HM-NW", to: "HM-N",  weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),

        // ── Hof ring → building entries (each connection stays clear of buildings) ──
        NavEdge(from: "HM-N",  to: "Door-Sporthalle", weight: 4,
                instruction: "nav.toSporthalleDirect", reverseInstruction: "nav.aroundCourtyard",
                icon: "figure.run", reverseIcon: "arrow.down",
                // Along the visible walkable strip south/east of Sporthalle.
                waypoints: [GeoCoord(lat: 50.927815, lon: 6.995710)]),
        NavEdge(from: "WC-SB-B-Sport", to: "HM-N", weight: 5,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.wcRight",
                icon: "figure.walk", reverseIcon: "figure.dress.line.vertical.figure",
                // Real exterior shortcut from the WC-B/Sport entrance onto the Hof
                // walkable ring. This prevents the router from using E009/Umkleide
                // or the bike approach as a through-corridor.
                waypoints: [GeoCoord(lat: 50.927835, lon: 6.995470)]),
        NavEdge(from: "HM-N",  to: "Hof", weight: 3,
                instruction: "nav.goToCourtyard", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "HM-NW", to: "MiddleB", weight: 8,
                instruction: "nav.goToMiddleB", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.left", reverseIcon: "arrow.right", waypoints: []),
        NavEdge(from: "HM-W",  to: "MiddleB", weight: 8,
                instruction: "nav.goToMiddleB", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.left", reverseIcon: "arrow.right", waypoints: []),
        NavEdge(from: "HM-SW", to: "SB-A-B", weight: 8,
                instruction: "nav.goToStairsAB", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "HM-S",  to: "Door-Mensa-EG", weight: 5,
                instruction: "nav.toMensaEG", reverseInstruction: "nav.aroundCourtyard",
                icon: "fork.knife", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "HM-S",  to: "SB-A-C", weight: 9,
                instruction: "nav.goToStairsAC", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []),
        NavEdge(from: "HM-SE", to: "MiddleC", weight: 8,
                instruction: "nav.goToMiddleC", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "HM-E",  to: "FlurC-N", weight: 6,
                instruction: "nav.enterCorridorC", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "HM-E",  to: "SB-C-Aula", weight: 4,
                instruction: "nav.goToStairsCAula", reverseInstruction: "nav.aroundCourtyard",
                icon: "arrow.right", reverseIcon: "arrow.left",
                // Enter C/Aula at the real WC-SB-C-Aula door after approaching from the Hof green area.
                waypoints: [GeoCoord(lat: 50.927590, lon: 6.996205)]),

        // ── Bike-path mesh: Fahrradabstellplatz → Door-Sporthalle (south of Sport block) ──
        NavEdge(from: "Fahrradabstellplatz", to: "BSP-1", weight: 5,
                instruction: "nav.fromBikeToBuilding", reverseInstruction: "nav.toBikeParking",
                icon: "arrow.down", reverseIcon: "arrow.up",
                // Follow the GREEN walkable bike→school polygon; do not draw through the Aula/D002 block.
                waypoints: [GeoCoord(lat: 50.927935, lon: 6.996100)]),
        NavEdge(from: "BSP-1", to: "BSP-2", weight: 6,
                instruction: "nav.fromBikeToBuilding", reverseInstruction: "nav.toBikeParking",
                icon: "arrow.left", reverseIcon: "arrow.right",
                waypoints: [GeoCoord(lat: 50.927900, lon: 6.995955)]),
        NavEdge(from: "BSP-2", to: "BSP-3", weight: 6,
                instruction: "nav.fromBikeToBuilding", reverseInstruction: "nav.toBikeParking",
                icon: "arrow.left", reverseIcon: "arrow.right",
                waypoints: [GeoCoord(lat: 50.927805, lon: 6.995820)]),
        NavEdge(from: "BSP-3", to: "Door-Sporthalle", weight: 4,
                instruction: "nav.toSporthalleDirect", reverseInstruction: "nav.fromBikeToBuilding",
                icon: "figure.run", reverseIcon: "arrow.right", waypoints: []),
        // From bike-path, also reach the Hof ring NE
        NavEdge(from: "BSP-3", to: "HM-NE", weight: 8,
                instruction: "nav.aroundCourtyard", reverseInstruction: "nav.fromBikeToBuilding",
                icon: "arrow.down", reverseIcon: "arrow.up",
                // Green walkable area connector from bike path into the Hof ring.
                // This is the correct way from Parkplatz-Eingang/Fahrradbereich toward Aula.
                waypoints: [
                    GeoCoord(lat: 50.927740, lon: 6.995850),
                    GeoCoord(lat: 50.927735, lon: 6.995970)
                ]),

        // ── Door-Sporthalle: shortest path INTO Sporthalle/Umkleide ──
        NavEdge(from: "Door-Sporthalle", to: "Sporthalle", weight: 6,
                instruction: "nav.enterGym", reverseInstruction: "nav.leaveGym",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open", waypoints: []),
        NavEdge(from: "Door-Sporthalle", to: "Umkleide", weight: 4,
                instruction: "nav.goToChangingRoom", reverseInstruction: "nav.leaveGym",
                icon: "door.left.hand.open", reverseIcon: "arrow.right", waypoints: []),

        // ── Door-Mensa-EG: shortest path INTO Forum/Cafeteria ──
        NavEdge(from: "Door-Mensa-EG", to: "A-Forum", weight: 4,
                instruction: "nav.goToForum", reverseInstruction: "nav.toMensaEG",
                icon: "door.left.hand.open", reverseIcon: "door.left.hand.open", waypoints: []),
        NavEdge(from: "Door-Mensa-EG", to: "A-Kiosk", weight: 7,
                instruction: "nav.goToKiosk", reverseInstruction: "nav.toMensaEG",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),

        // ── Named A-block rooms ──
        re("A001", "A-Forum", 5, "nav.goToForum"),
        re("A002", "A-Forum", 8, "nav.goToForum"),
        re("A003", "SB-A-B",  6, "nav.goToStairsAB"),
        re("A007", "A-Kiosk", 4, "nav.goToKiosk"),

        // Elevator A
        NavEdge(from: "Aufzug-A", to: "SB-A-B", weight: 4,
                instruction: "nav.toStairsAB", reverseInstruction: "nav.toElevatorA",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),
        NavEdge(from: "Aufzug-A", to: "A-Forum", weight: 6,
                instruction: "nav.goToForum", reverseInstruction: "nav.toElevatorA",
                icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []),

        // ── E-block rooms (near Sporthalle / SB-B-Sport) ──
        re("E009", "SB-B-Sport", 4, "nav.toStairsBSport"),
        re("E010", "SB-B-Sport", 5, "nav.toStairsBSport"),

        // ── D-block (Stuhllager near Aula) ──
        re("D002", "Aula", 4, "nav.enterAula"),
    ]

    // MARK: - Upper Floor Edges
    static let upperFloorEdges: [NavEdge] = {
        var edges = [NavEdge]()

        // Stairs up — connect each staircase to the closest corridor segment on OG
        edges.append(NavEdge(from: "SB-B-Sport", to: "FlurB-OG-N", weight: 8,
                             instruction: "nav.stairsUpCorridorB", reverseInstruction: "nav.stairsDownCorridorB",
                             icon: "stairs", reverseIcon: "stairs",
                             waypoints: [bCorridorNorth]))
        edges.append(NavEdge(from: "SB-A-B", to: "FlurB-OG-S", weight: 8,
                             instruction: "nav.stairsUpCorridorB", reverseInstruction: "nav.stairsDownCorridorB",
                             icon: "stairs", reverseIcon: "stairs",
                             waypoints: [bCorridorSouth]))
        edges.append(NavEdge(from: "SB-A-C", to: "FlurC-OG-S", weight: 8,
                             instruction: "nav.stairsUpCorridorC", reverseInstruction: "nav.stairsDownCorridorC",
                             icon: "stairs", reverseIcon: "stairs",
                             waypoints: [cCorridorSouth]))
        edges.append(NavEdge(from: "SB-C-Aula", to: "FlurC-OG-N", weight: 8,
                             instruction: "nav.stairsUpCorridorC", reverseInstruction: "nav.stairsDownCorridorC",
                             icon: "stairs", reverseIcon: "stairs",
                             waypoints: [cCorridorNorth]))

        // Upper corridor segment chain
        edges.append(NavEdge(from: "FlurB-OG-N", to: "FlurB-OG-M", weight: 12,
                             instruction: "nav.continueCorridorB", reverseInstruction: "nav.continueCorridorB",
                             icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []))
        edges.append(NavEdge(from: "FlurB-OG-M", to: "FlurB-OG-S", weight: 12,
                             instruction: "nav.continueCorridorB", reverseInstruction: "nav.continueCorridorB",
                             icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []))
        edges.append(NavEdge(from: "FlurB-OG-M", to: "MiddleB-OG", weight: 3,
                             instruction: "nav.goToMiddleBOG", reverseInstruction: "nav.goToCorridorBOG",
                             icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []))

        edges.append(NavEdge(from: "FlurC-OG-N", to: "FlurC-OG-M", weight: 12,
                             instruction: "nav.continueCorridorC", reverseInstruction: "nav.continueCorridorC",
                             icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []))
        edges.append(NavEdge(from: "FlurC-OG-M", to: "FlurC-OG-S", weight: 12,
                             instruction: "nav.continueCorridorC", reverseInstruction: "nav.continueCorridorC",
                             icon: "arrow.down", reverseIcon: "arrow.up", waypoints: []))
        edges.append(NavEdge(from: "FlurC-OG-M", to: "MiddleC-OG", weight: 3,
                             instruction: "nav.goToMiddleCOG", reverseInstruction: "nav.goToCorridorCOG",
                             icon: "arrow.right", reverseIcon: "arrow.left", waypoints: []))

        // B upper floor rooms → nearest upper corridor segment
        let bMap: [(Int, String, String)] = [
            (1, "FlurB-OG-N", "nav.goToCorridorBOG"), (2, "FlurB-OG-N", "nav.goToCorridorBOG"),
            (3, "FlurB-OG-N", "nav.goToCorridorBOG"), (4, "FlurB-OG-N", "nav.goToCorridorBOG"),
            (5, "FlurB-OG-M", "nav.goToCorridorBOG"), (6, "FlurB-OG-M", "nav.goToCorridorBOG"),
            (7, "MiddleB-OG",  "nav.goToMiddleBOG"),  (8, "MiddleB-OG",  "nav.goToMiddleBOG"),
            (9, "FlurB-OG-S", "nav.goToCorridorBOG"), (10,"FlurB-OG-S", "nav.goToCorridorBOG"),
            (11,"FlurB-OG-S", "nav.goToCorridorBOG"), (12,"FlurB-OG-S", "nav.goToCorridorBOG"),
        ]
        let weights: [Double] = [4,4,6,6,5,5,5,5,6,6,4,4]
        for (i, corridor, instrKey) in bMap {
            edges.append(re("B\(i)-OG", corridor, weights[i-1], instrKey))
        }

        let cMap: [(Int, String, String)] = [
            (1, "FlurC-OG-N", "nav.goToCorridorCOG"), (2, "FlurC-OG-N", "nav.goToCorridorCOG"),
            (3, "FlurC-OG-N", "nav.goToCorridorCOG"), (4, "FlurC-OG-N", "nav.goToCorridorCOG"),
            (5, "FlurC-OG-M", "nav.goToCorridorCOG"), (6, "FlurC-OG-M", "nav.goToCorridorCOG"),
            (7, "MiddleC-OG",  "nav.goToMiddleCOG"),  (8, "MiddleC-OG",  "nav.goToMiddleCOG"),
            (9, "FlurC-OG-S", "nav.goToCorridorCOG"), (10,"FlurC-OG-S", "nav.goToCorridorCOG"),
            (11,"FlurC-OG-S", "nav.goToCorridorCOG"), (12,"FlurC-OG-S", "nav.goToCorridorCOG"),
        ]
        for (i, corridor, instrKey) in cMap {
            edges.append(re("C\(i)-OG", corridor, weights[i-1], instrKey))
        }

        return edges
    }()

    static let edges: [NavEdge] = groundFloorEdges + upperFloorEdges

    // MARK: - Adjacency
    struct AdjEntry {
        let neighbor: String
        let weight: Double
        let instruction: String
        let icon: String
        let waypoints: [GeoCoord]
    }

    static let adjacency: [String: [AdjEntry]] = {
        var adj = [String: [AdjEntry]]()
        for edge in edges {
            adj[edge.from, default: []].append(AdjEntry(
                neighbor: edge.to, weight: edge.weight,
                instruction: edge.instruction, icon: edge.icon, waypoints: edge.waypoints))
            adj[edge.to, default: []].append(AdjEntry(
                neighbor: edge.from, weight: edge.weight,
                instruction: edge.reverseInstruction, icon: edge.reverseIcon,
                waypoints: edge.waypoints.reversed()))
        }
        return adj
    }()

    static func node(by id: String) -> NavNode? { nodes.first { $0.id == id } }
    static var selectableNodes: [NavNode] { nodes.filter { $0.isNavigable } }

    // MARK: - Route geometry validation

    private static func isOutdoorLike(_ node: NavNode) -> Bool {
        node.block == "Außen" || node.block == "Hof" || node.block.isEmpty ||
        node.category == .courtyard || node.category == .parking || node.category == .bike || node.category == .entrance
    }

    private static func point(_ p: GeoCoord, inside polygon: [GeoCoord]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var isInside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            let crossesY = (pi.lat > p.lat) != (pj.lat > p.lat)
            if crossesY {
                let xAtY = (pj.lon - pi.lon) * (p.lat - pi.lat) / ((pj.lat - pi.lat) + 0.000000000001) + pi.lon
                if p.lon < xAtY { isInside.toggle() }
            }
            j = i
        }
        return isInside
    }

    private static func orientation(_ a: GeoCoord, _ b: GeoCoord, _ c: GeoCoord) -> Double {
        (b.lon - a.lon) * (c.lat - a.lat) - (b.lat - a.lat) * (c.lon - a.lon)
    }

    private static func onSegment(_ a: GeoCoord, _ b: GeoCoord, _ p: GeoCoord) -> Bool {
        let eps = 0.0000000001
        return min(a.lon, b.lon) - eps <= p.lon && p.lon <= max(a.lon, b.lon) + eps &&
               min(a.lat, b.lat) - eps <= p.lat && p.lat <= max(a.lat, b.lat) + eps &&
               abs(orientation(a, b, p)) < eps
    }

    private static func segmentsIntersect(_ a: GeoCoord, _ b: GeoCoord, _ c: GeoCoord, _ d: GeoCoord) -> Bool {
        let o1 = orientation(a, b, c)
        let o2 = orientation(a, b, d)
        let o3 = orientation(c, d, a)
        let o4 = orientation(c, d, b)
        if (o1 > 0) != (o2 > 0), (o3 > 0) != (o4 > 0) { return true }
        return onSegment(a, b, c) || onSegment(a, b, d) || onSegment(c, d, a) || onSegment(c, d, b)
    }

    private static func segment(_ a: GeoCoord, _ b: GeoCoord, intersects polygon: [GeoCoord]) -> Bool {
        guard polygon.count >= 3 else { return false }
        if point(a, inside: polygon) || point(b, inside: polygon) { return true }
        for i in 0..<polygon.count {
            let c = polygon[i]
            let d = polygon[(i + 1) % polygon.count]
            if segmentsIntersect(a, b, c, d) { return true }
        }
        return false
    }

    private static func segment(_ a: GeoCoord, _ b: GeoCoord, intersectsLine line: [GeoCoord]) -> Bool {
        guard line.count >= 2 else { return false }
        for i in 1..<line.count {
            if segmentsIntersect(a, b, line[i - 1], line[i]) { return true }
        }
        return false
    }

    private static func isDoorNode(_ node: NavNode) -> Bool {
        node.id.hasPrefix("Door-")
    }

    private static func segmentUsesDoorEndpoint(_ a: GeoCoord, _ b: GeoCoord, _ fromNode: NavNode, _ toNode: NavNode) -> Bool {
        // Entering/leaving a building may touch the wall exactly at an explicit Door-* node.
        // That is intentional; random intersections elsewhere are still logged.
        return isDoorNode(fromNode) || isDoorNode(toNode)
    }

    private static func polyline(for edge: NavEdge) -> [GeoCoord]? {
        guard let from = node(by: edge.from), let to = node(by: edge.to) else { return nil }
        return [from.coordinate] + edge.waypoints + [to.coordinate]
    }

    static func validateRouteGeometry() {
        guard routeDebugLoggingEnabled else { return }
        var issueCount = 0
        let indoorBlocks: Set<String> = ["A", "B", "C", "Sport", "Aula"]

        for edge in edges {
            guard let fromNode = node(by: edge.from),
                  let toNode = node(by: edge.to),
                  let coords = polyline(for: edge),
                  coords.count >= 2 else {
                print("❌ ROUTE GRAPH: missing node for edge \(edge.from) → \(edge.to)")
                issueCount += 1
                continue
            }

            for i in 1..<coords.count {
                let a = coords[i - 1]
                let b = coords[i]

                for forbidden in forbiddenAreas where segment(a, b, intersects: forbidden.corners) {
                    print("❌ ROUTE GEOMETRY: \(edge.from) → \(edge.to) crosses forbidden area \(forbidden.id)")
                    issueCount += 1
                }

                if segment(a, b, intersectsLine: physicalWallLine),
                   !segmentUsesDoorEndpoint(a, b, fromNode, toNode) {
                    print("❌ ROUTE GEOMETRY: \(edge.from) → \(edge.to) crosses physical wall line")
                    issueCount += 1
                }

                // Building polygons are allowed for indoor edges. Only warn when an
                // outdoor/helper edge crosses an unrelated building footprint.
                if isOutdoorLike(fromNode) || isOutdoorLike(toNode) {
                    for building in buildingOutlines {
                        let edgeIsInsideItsOwnBuilding = indoorBlocks.contains(fromNode.block) && fromNode.block == building.id ||
                                                          indoorBlocks.contains(toNode.block) && toNode.block == building.id
                        if !edgeIsInsideItsOwnBuilding && !segmentUsesDoorEndpoint(a, b, fromNode, toNode) && segment(a, b, intersects: building.corners) {
                            print("❌ ROUTE GEOMETRY: \(edge.from) → \(edge.to) crosses building \(building.id)")
                            issueCount += 1
                        }
                    }
                }
            }

            if edge.waypoints.isEmpty && (isOutdoorLike(fromNode) || isOutdoorLike(toNode)) {
                let from = CLLocation(latitude: fromNode.coordinate.lat, longitude: fromNode.coordinate.lon)
                let to = CLLocation(latitude: toNode.coordinate.lat, longitude: toNode.coordinate.lon)
                if from.distance(from: to) > 25 {
                    print("⚠️ ROUTE GEOMETRY: long outdoor/helper edge without waypoints: \(edge.from) → \(edge.to)")
                }
            }
        }

        if issueCount == 0 {
            print("✅ ROUTE GEOMETRY: no forbidden/building crossings detected in checked outdoor/helper edges")
        } else {
            print("❌ ROUTE GEOMETRY: \(issueCount) issue(s) detected")
        }
    }

    // MARK: - Routing cost policy

    private static func isTransitDeadEndCategory(_ category: NavNode.NodeCategory) -> Bool {
        switch category {
        case .room, .special, .sport, .food:
            return true
        default:
            return false
        }
    }

    private static func isBikeApproachNode(_ id: String) -> Bool {
        id == "Fahrradabstellplatz" || id.hasPrefix("BSP-")
    }

    private static func routeUsesBikeApproach(_ startID: String, _ endID: String) -> Bool {
        let bikeRelevant: Set<String> = ["Fahrradabstellplatz", "Haupteingang", "Eingang"]
        return bikeRelevant.contains(startID) || bikeRelevant.contains(endID)
    }

    private static func dynamicPenalty(current: String, neighbor: String, startID: String, endID: String) -> Double {
        guard let neighborNode = node(by: neighbor) else { return 0 }

        // Rooms and destinations may be start/end, but they should not be used as
        // shortcuts. This fixes routes like WC (B/Sport) → Aula that previously
        // walked through Umkleide/Sporthalle just because that edge was cheap.
        if neighbor != endID && neighbor != startID && isTransitDeadEndCategory(neighborNode.category) {
            return 900
        }

        // The BSP nodes are only the bike approach from Fahrradabstellplatz/entrances.
        // For building-to-building routes, strongly prefer the Hof ring mesh.
        if isBikeApproachNode(neighbor) && !routeUsesBikeApproach(startID, endID) {
            return 500
        }

        // Do not use the visual center of the car parking as a transit shortcut.
        // The grey walkable overlays describe the path around the parking area; the
        // center point is only a selectable destination/start, not a through-node.
        if neighbor == "Parkplatz" && neighbor != endID && current != "Parkplatz" {
            return 700
        }

        return 0
    }

    // MARK: - Dijkstra
    static func findRoute(from startID: String, to endID: String) -> [NavStep] {
        guard let startNode = node(by: startID), let endNode = node(by: endID) else {
            return [NavStep(instruction: L.s("nav.roomNotFound"), icon: "xmark.circle", coordinate: nil, pathCoordinates: [], floor: 0)]
        }
        if startID == endID {
            return [NavStep(instruction: L.s("nav.alreadyHere"), icon: "checkmark.circle.fill",
                            coordinate: startNode.coordinate, pathCoordinates: [], floor: startNode.floor)]
        }

        var dist = [String: Double]()
        var prev = [String: String]()
        var edgeUsed = [String: (String, String, [GeoCoord])]()
        var visited = Set<String>()
        dist[startID] = 0

        while true {
            let candidate = dist.filter { !visited.contains($0.key) }.min(by: { $0.value < $1.value })
            guard let (current, currentDist) = candidate else { break }
            if current == endID { break }
            visited.insert(current)
            for entry in adjacency[current] ?? [] {
                let newDist = currentDist + entry.weight + dynamicPenalty(current: current, neighbor: entry.neighbor, startID: startID, endID: endID)
                if newDist < (dist[entry.neighbor] ?? .infinity) {
                    dist[entry.neighbor] = newDist
                    prev[entry.neighbor] = current
                    edgeUsed[entry.neighbor] = (entry.instruction, entry.icon, entry.waypoints)
                }
            }
        }

        guard dist[endID] != nil else {
            return [NavStep(instruction: L.s("nav.noRoute"), icon: "exclamationmark.triangle", coordinate: nil, pathCoordinates: [], floor: 0)]
        }

        var path = [String]()
        var cur = endID
        while cur != startID { path.append(cur); guard let p = prev[cur] else { break }; cur = p }
        path.append(startID); path.reverse()

        if routeDebugLoggingEnabled {
            print("🧭 ROUTE PATH:", path.joined(separator: " → "))
        }

        var steps = [NavStep]()
        steps.append(NavStep(instruction: "\(L.s("nav.start")): \(startNode.displayName)",
                             icon: "location.circle.fill", coordinate: startNode.coordinate,
                             pathCoordinates: [startNode.coordinate], floor: startNode.floor))

        for i in 1..<path.count {
            let nodeID = path[i]
            let n = node(by: nodeID)
            let (instrKey, icon, wps) = edgeUsed[nodeID] ?? ("nav.continue", "arrow.forward", [])

            var seg = [GeoCoord]()
            if let prevN = node(by: path[i - 1]) { seg.append(prevN.coordinate) }
            seg.append(contentsOf: wps)
            if let thisN = n { seg.append(thisN.coordinate) }

            let resolved = instrKey == "nav.goToRoom" ? "\(L.s("nav.goToRoom")) \(nodeID)" : L.s(instrKey)
            steps.append(NavStep(instruction: resolved, icon: icon, coordinate: n?.coordinate,
                                 pathCoordinates: seg, floor: n?.floor ?? 0))
        }

        let minutes = max(1, Int(dist[endID] ?? 0) / 60)
        steps.append(NavStep(
            instruction: "\(L.s("nav.arrived")): \(endNode.displayName) (~\(minutes) \(L.s("nav.approxMin")))",
            icon: "checkmark.circle.fill", coordinate: endNode.coordinate, pathCoordinates: [],
            floor: endNode.floor))
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

    // Persistent, Apple Maps-style bottom sheet — never dismissed, only resized.
    @State private var showRouteSheet = true
    @State private var sheetDetent: PresentationDetent = .height(130)
    private let sheetCollapsedHeight: CGFloat = 130
    private let sheetNavHeight: CGFloat = 92

    private let arrivalThreshold: Double = 12.0
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptics = UIImpactFeedbackGenerator(style: .light)
    private let successHaptics = UINotificationFeedbackGenerator()

    private var isActivelyNavigating: Bool { isNavigating || isDemoMode }

    var body: some View {
        ZStack(alignment: .top) {
            mapView
                .ignoresSafeArea(edges: .bottom)

            if isActivelyNavigating {
                navigationCard
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(spacing: 10) {
                Spacer()
                floorToggle
                locateMeButton
            }
            .padding(.trailing, 12)
            .padding(.bottom, (isActivelyNavigating ? sheetNavHeight : sheetCollapsedHeight) + 16)
        }
        .animation(.easeInOut(duration: 0.25), value: isActivelyNavigating)
        .sheet(isPresented: $showRouteSheet) {
            routeSheetContent
                .presentationDetents(
                    [.height(sheetNavHeight), .height(sheetCollapsedHeight), .medium, .large],
                    selection: $sheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled()
        }
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
        .onChange(of: isNavigating) { _, _ in syncSheetDetent() }
        .onChange(of: isDemoMode) { _, _ in syncSheetDetent() }
        .onReceive(locationManager.$lastLocation) { loc in
            guard isNavigating, !isDemoMode, let loc = loc else { return }
            updateNavigation(userLocation: loc)
        }
        .onAppear { SchoolGraph.validateRouteGeometry() }
        .onDisappear { stopAll() }
    }

    private func syncSheetDetent() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if isActivelyNavigating {
                sheetDetent = .height(sheetNavHeight)
            } else {
                sheetDetent = route.isEmpty ? .height(sheetCollapsedHeight) : .medium
            }
        }
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

    private var locateMeButton: some View {
        Button { locateUser() } label: {
            ZStack {
                if locating {
                    ProgressView().progressViewStyle(.circular).tint(GSOColors.primary).scaleEffect(0.7)
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(GSOColors.primary)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .gsoFloatingButton()
        .disabled(locating)
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
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
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

    // MARK: - Bottom Sheet (Apple Maps-style)

    @ViewBuilder
    private var routeSheetContent: some View {
        if isActivelyNavigating {
            navActiveBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    searchFields
                    if !route.isEmpty {
                        routeSummaryCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
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
                            sheetDetent = .medium
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
                        sheetDetent = .height(sheetCollapsedHeight)
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
