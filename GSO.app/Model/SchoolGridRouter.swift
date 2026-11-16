import Foundation
import CoreLocation

/// Indoor/outdoor router based on a walkability grid generated from the school's CAD floor plan
/// (`SchoolGrid.bin`, built by `Tools/school-grid/build_school_grid.py`).
///
/// Every 0.25 m cell is either blocked (wall, window, Hof pit, grass behind the buildings) or
/// tagged with a zone. Routes are found with A* on this grid, so they can only pass through real
/// doors and the confirmed entrances — never through a wall. Turn-by-turn steps are derived from
/// the zones the route passes through (corridor → stair house → Hof → ...).
final class SchoolGridRouter {

    static let shared: SchoolGridRouter? = SchoolGridRouter()

    enum Zone: UInt8 {
        case blocked = 0, hof, outdoor, corridorB, middleB, corridorC, middleC, forum
        case stairsAB, stairsAC, stairsBSport, stairsCAula, sport, aula
        case roomB, roomC, roomA, parking, bike

        var isStairs: Bool { [.stairsAB, .stairsAC, .stairsBSport, .stairsCAula].contains(self) }
        var isOutside: Bool { [.outdoor, .parking, .bike].contains(self) }
        /// Rooms may be the start or destination but must never be used as a shortcut.
        var isRoom: Bool { [.roomA, .roomB, .roomC, .sport, .aula].contains(self) }
    }

    private struct Run {
        let floor: Int
        let zone: Zone
        var cells: [Int]
    }

    // Grid
    private let width: Int
    private let height: Int
    private let cellCount: Int
    private let floors: [[UInt8]]          // zone in bits 0-4, wall clearance (0-3) in bits 5-6
    private let rooms: [UInt8]             // room component id, 0 = not a room
    private var stairLinks: [Int: Int] = [:]   // state -> state (state = floor * cellCount + cell)

    // Plan <-> GPS transform
    private let cellSize, originX, originTop: Double
    private let a, b, tx, ty, lat0, lon0, kN, kE: Double

    private static let stairCost: Float = 60            // ~15 m walking equivalent
    private static let roomShortcutFactor: Float = 4
    private static let clearancePenalty: [Float] = [0, 1.5, 0.4, 0]

    // MARK: - Loading

    private init?() {
        guard let url = Bundle.main.url(forResource: "SchoolGrid", withExtension: "bin"),
              let data = try? Data(contentsOf: url), data.count > 112,
              data.prefix(4) == Data("GSOG".utf8) else { return nil }

        func u32(_ o: Int) -> Int { Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: o, as: UInt32.self) }) }
        func f64(_ o: Int) -> Double { data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: o, as: Double.self) } }

        width = u32(8); height = u32(12); cellCount = width * height
        cellSize = f64(16); originX = f64(24); originTop = f64(32)
        a = f64(40); b = f64(48); tx = f64(56); ty = f64(64)
        lat0 = f64(72); lon0 = f64(80); kN = f64(88); kE = f64(96)

        let linkCount = u32(104)
        var offset = 108
        var links: [(Int, Int)] = []
        for _ in 0..<linkCount {
            links.append((u32(offset), u32(offset + 4)))
            offset += 12
        }
        let payloadLength = u32(offset)
        offset += 4
        guard data.count >= offset + payloadLength,
              let raw = try? (data.subdata(in: offset..<offset + payloadLength) as NSData).decompressed(using: .zlib) as Data,
              raw.count == cellCount * 3 else { return nil }

        let bytes = [UInt8](raw)
        floors = [Array(bytes[0..<cellCount]), Array(bytes[cellCount..<2 * cellCount])]
        rooms = Array(bytes[2 * cellCount..<3 * cellCount])
        for (ground, upper) in links {
            stairLinks[ground] = cellCount + upper
            stairLinks[cellCount + upper] = ground
        }
    }

    // MARK: - Coordinates

    private func zone(_ floor: Int, _ cell: Int) -> Zone { Zone(rawValue: floors[floor][cell] & 31) ?? .blocked }
    private func clearance(_ floor: Int, _ cell: Int) -> Int { Int(floors[floor][cell] >> 5) & 3 }

    private func coordinate(ofCell cell: Int) -> GeoCoord {
        let x = originX + (Double(cell % width) + 0.5) * cellSize
        let y = originTop - (Double(cell / width) + 0.5) * cellSize
        let e = a * x - b * y + tx
        let n = b * x + a * y + ty
        return GeoCoord(lat: lat0 + n / kN, lon: lon0 + e / kE)
    }

    private func cellPosition(of coord: GeoCoord) -> (x: Int, y: Int) {
        let e = (coord.lon - lon0) * kE - tx
        let n = (coord.lat - lat0) * kN - ty
        let s2 = a * a + b * b
        let x = (a * e + b * n) / s2
        let y = (-b * e + a * n) / s2
        return (Int((x - originX) / cellSize), Int((originTop - y) / cellSize))
    }

    /// Zones a node is allowed to snap into, so e.g. a room marker next to a wall never snaps
    /// into the corridor on the other side.
    private func allowedZones(for node: NavNode) -> Set<Zone> {
        if node.floor > 0 { return [] }
        switch node.block {
        case "A": return [.forum, .roomA]
        case "B": return [.roomB, .corridorB, .middleB]
        case "C": return [.roomC, .corridorC, .middleC]
        case "Sport": return [.sport]
        case "Aula": return [.aula]
        case "Hof": return [.hof]
        case "Außen": return [.outdoor, .parking, .bike]
        case "": return [.stairsAB, .stairsAC, .stairsBSport, .stairsCAula, .hof]
        default: return []
        }
    }

    /// Nearest walkable cell (within 15 m) for a node, preferring the node's own zones.
    private func snap(_ node: NavNode) -> Int? {
        let floor = min(node.floor, floors.count - 1)
        let preferred = allowedZones(for: node)
        let (cx, cy) = cellPosition(of: node.coordinate)
        for zones in [preferred, []] {
            for r in 0..<60 {
                var best: (d: Int, cell: Int)?
                for dx in -r...r {
                    let dys = abs(dx) == r ? Array(-r...r) : [-r, r]
                    for dy in dys {
                        let x = cx + dx, y = cy + dy
                        guard x >= 0, x < width, y >= 0, y < height else { continue }
                        let cell = y * width + x
                        let z = zone(floor, cell)
                        guard z != .blocked, zones.isEmpty || zones.contains(z) else { continue }
                        let d = dx * dx + dy * dy
                        if best == nil || d < best!.d { best = (d, cell) }
                    }
                }
                if let best { return floor * cellCount + best.cell }
            }
        }
        return nil
    }

    // MARK: - A*

    private func findPath(from start: Int, to goal: Int) -> [Int]? {
        let n = cellCount
        let goalFloor = goal / n, goalCell = goal % n
        let gx = goalCell % width, gy = goalCell / width
        let allowedRooms: Set<UInt8> = [rooms[start % n], rooms[goalCell]]

        var gScore = [Float](repeating: .infinity, count: 2 * n)
        var cameFrom = [Int32](repeating: -1, count: 2 * n)
        var closed = [Bool](repeating: false, count: 2 * n)
        var heap = MinHeap()

        func heuristic(_ state: Int) -> Float {
            let c = state % n
            let dx = Float(abs(c % width - gx)), dy = Float(abs(c / width - gy))
            return max(dx, dy) + 0.41421356 * min(dx, dy) + (state / n != goalFloor ? Self.stairCost : 0)
        }

        gScore[start] = 0
        heap.push(heuristic(start), start)
        let moves: [(Int, Int, Float)] = [(1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1),
                                          (1, 1, 1.41421356), (1, -1, 1.41421356), (-1, 1, 1.41421356), (-1, -1, 1.41421356)]

        while let (_, state) = heap.pop() {
            if state == goal { break }
            if closed[state] { continue }
            closed[state] = true
            let floor = state / n, cell = state % n
            let g = gScore[state]
            let x = cell % width, y = cell / width
            let grid = floors[floor]

            for (dx, dy, base) in moves {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                let next = ny * width + nx
                let raw = grid[next]
                guard raw & 31 != 0 else { continue }
                // No corner cutting: diagonal moves need both orthogonal neighbours free.
                if dx != 0 && dy != 0 && (grid[y * width + nx] & 31 == 0 || grid[ny * width + x] & 31 == 0) { continue }

                var cost = base * (1 + Self.clearancePenalty[Int(raw >> 5) & 3])
                if let z = Zone(rawValue: raw & 31), z.isRoom, !allowedRooms.contains(rooms[next]) {
                    cost *= Self.roomShortcutFactor
                }
                let nextState = floor * n + next
                if g + cost < gScore[nextState] {
                    gScore[nextState] = g + cost
                    cameFrom[nextState] = Int32(state)
                    heap.push(g + cost + heuristic(nextState), nextState)
                }
            }
            if let linked = stairLinks[state], g + Self.stairCost < gScore[linked] {
                gScore[linked] = g + Self.stairCost
                cameFrom[linked] = Int32(state)
                heap.push(g + Self.stairCost + heuristic(linked), linked)
            }
        }

        guard gScore[goal] < .infinity else { return nil }
        var path = [goal]
        while let last = path.last, last != start {
            let prev = Int(cameFrom[last])
            guard prev >= 0 else { return nil }
            path.append(prev)
        }
        return path.reversed()
    }

    // MARK: - Smoothing

    /// True if the straight line between two cells only crosses cells with at least `minClearance`.
    private func lineOfSight(_ floor: Int, _ c0: Int, _ c1: Int, minClearance: Int) -> Bool {
        let x0 = Double(c0 % width), y0 = Double(c0 / width)
        let x1 = Double(c1 % width), y1 = Double(c1 / width)
        let samples = Int(max(abs(x1 - x0), abs(y1 - y0))) * 2 + 1
        for k in 0...samples {
            let t = Double(k) / Double(samples)
            let x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t
            // Check both neighbours when the line passes exactly between two cells.
            for eps in [-1e-6, 1e-6] {
                let cell = Int((y + 0.5 + eps).rounded(.down)) * width + Int((x + 0.5 + eps).rounded(.down))
                if clearance(floor, cell) < minClearance { return false }
            }
        }
        return true
    }

    /// String pulling: keep only the cells needed so that every straight segment stays walkable
    /// and keeps at least the wall distance the original path had.
    private func smooth(_ run: Run) -> [Int] {
        let cells = run.cells
        guard cells.count > 2 else { return cells }
        var anchors = [cells[0]]
        var k = 0
        while k < cells.count - 1 {
            var best = k + 1
            var minClr = min(2, clearance(run.floor, cells[k]), clearance(run.floor, cells[k + 1]))
            var j = k + 2
            while j < cells.count {
                minClr = min(minClr, clearance(run.floor, cells[j]))
                if !lineOfSight(run.floor, cells[k], cells[j], minClearance: max(1, minClr)) { break }
                best = j
                j += 1
            }
            anchors.append(cells[best])
            k = best
        }
        return anchors
    }

    // MARK: - Route → steps

    func route(from start: NavNode, to end: NavNode) -> [NavStep]? {
        guard let s = snap(start), let t = snap(end), let path = findPath(from: s, to: t) else { return nil }

        // Split the path into runs of the same floor + zone.
        var runs: [Run] = []
        for state in path {
            let floor = state / cellCount, cell = state % cellCount
            let z = zone(floor, cell)
            if let last = runs.last, last.floor == floor, last.zone == z {
                runs[runs.count - 1].cells.append(cell)
            } else {
                runs.append(Run(floor: floor, zone: z, cells: [cell]))
            }
        }
        runs = mergeShortRuns(runs)

        if SchoolGraph.routeDebugLoggingEnabled {
            print("🧭 GRID ROUTE:", runs.map { "\($0.zone)\($0.floor > 0 ? "(OG)" : "")" }.joined(separator: " → "))
        }

        var steps = [NavStep(instruction: "\(L.s("nav.start")): \(start.displayName)",
                             icon: "location.circle.fill", coordinate: start.coordinate,
                             pathCoordinates: [start.coordinate], floor: start.floor)]
        var previous: [GeoCoord] = [start.coordinate]
        var totalDistance = 0.0

        for (k, run) in runs.enumerated() {
            var line = smooth(run).map(coordinate(ofCell:))
            if let joint = previous.last { line.insert(joint, at: 0) }
            totalDistance += polylineLength(line)

            let (key, icon) = instruction(for: k, in: runs, end: end, previous: previous, line: line)
            let text = k == runs.count - 1 ? "\(L.s("nav.goTo")) \(end.displayName)" : L.s(key)
            steps.append(NavStep(instruction: text, icon: icon, coordinate: line.last,
                                 pathCoordinates: line, floor: run.floor))
            previous = line
        }

        let minutes = max(1, Int(totalDistance / 60))
        steps.append(NavStep(instruction: "\(L.s("nav.arrived")): \(end.displayName) (~\(minutes) \(L.s("nav.approxMin")))",
                             icon: "checkmark.circle.fill", coordinate: end.coordinate, pathCoordinates: [],
                             floor: end.floor))
        return steps
    }

    /// Short runs (< 3 m, e.g. a door frame tagged as Hof) are folded into the previous run so
    /// they don't produce their own instruction. Runs next to a floor change are kept.
    private func mergeShortRuns(_ input: [Run]) -> [Run] {
        let minCells = Int(3.0 / 0.25)
        var runs = input
        var k = 1
        while k < runs.count - 1 {
            if runs[k].cells.count < minCells, runs[k - 1].floor == runs[k].floor, runs[k + 1].floor == runs[k].floor {
                runs[k - 1].cells += runs[k].cells
                runs.remove(at: k)
            } else {
                k += 1
            }
        }
        if runs.count > 1, runs[0].cells.count < minCells, runs[0].floor == runs[1].floor {
            runs[1].cells = runs[0].cells + runs[1].cells
            runs.removeFirst()
        }
        // Outdoor paths, car park and bike stands read as one outdoor walk.
        runs = runs.map { $0.zone.isOutside ? Run(floor: $0.floor, zone: .outdoor, cells: $0.cells) : $0 }
        // A stair house only passed through between two Hof segments is part of the Hof walk.
        for k in runs.indices.dropFirst().dropLast() where runs[k].zone.isStairs
            && runs[k - 1].zone == .hof && runs[k + 1].zone == .hof
            && runs[k - 1].floor == runs[k].floor && runs[k + 1].floor == runs[k].floor {
            runs[k] = Run(floor: runs[k].floor, zone: .hof, cells: runs[k].cells)
        }
        var merged: [Run] = []
        for run in runs {
            if let last = merged.last, last.floor == run.floor, last.zone == run.zone {
                merged[merged.count - 1].cells += run.cells
            } else {
                merged.append(run)
            }
        }
        // The destination room itself becomes part of the last step ("Gehe zu C009").
        if merged.count > 1, let last = merged.last, last.zone.isRoom, merged[merged.count - 2].floor == last.floor {
            merged[merged.count - 2].cells += last.cells
            merged.removeLast()
        }
        return merged
    }

    private func instruction(for k: Int, in runs: [Run], end: NavNode,
                             previous: [GeoCoord], line: [GeoCoord]) -> (String, String) {
        let run = runs[k]
        guard k + 1 < runs.count else { return ("nav.goTo", "flag.fill") }
        let next = runs[k + 1]
        let turn = turnIcon(previous: previous, line: line)

        if next.floor != run.floor {
            return (next.floor > run.floor ? "nav.stairsUp" : "nav.stairsDown", "stairs")
        }
        if run.zone == .hof {
            return (courtyardInstruction(after: runs[(k + 1)...]), "figure.walk")
        }
        if run.zone.isOutside && next.zone == .hof {
            return ("nav.fromBikeToBuilding", "figure.walk")
        }

        let og = next.floor > 0
        switch next.zone {
        case .corridorB: return (og ? "nav.goToCorridorBOG" : "nav.goToCorridorB", turn)
        case .middleB: return (og ? "nav.goToMiddleBOG" : "nav.goToMiddleB", turn)
        case .corridorC: return (og ? "nav.goToCorridorCOG" : "nav.goToCorridorC", turn)
        case .middleC: return (og ? "nav.goToMiddleCOG" : "nav.goToMiddleC", turn)
        case .forum: return ("nav.goToForum", "door.left.hand.open")
        case .stairsAB: return ("nav.goToStairsAB", turn)
        case .stairsAC: return ("nav.goToStairsAC", turn)
        case .stairsBSport: return ("nav.goToStairsBSport", turn)
        case .stairsCAula: return ("nav.goToStairsCAula", turn)
        case .sport: return ("nav.enterGym", "figure.run")
        case .aula: return ("nav.enterAula", "door.left.hand.open")
        case .hof: return ("nav.goToCourtyard", "figure.walk")
        case .parking: return ("nav.toParking", "car.fill")
        case .bike: return ("nav.toBikeParking", "bicycle")
        case .outdoor:
            switch end.id {
            case "Haupteingang": return ("nav.toMainEntrance", "figure.walk")
            case "Eingang": return ("nav.toEntrance", "figure.walk")
            case "Parkplatz": return ("nav.toParking", "car.fill")
            case "Fahrradabstellplatz": return ("nav.toBikeParking", "bicycle")
            default: return ("nav.continue", turn)
            }
        case .roomA, .roomB, .roomC, .blocked: return ("nav.continue", turn)
        }
    }

    /// Names where the Hof crossing leads to: the first building zone after it
    /// (stair houses are skipped, they're only the way in).
    private func courtyardInstruction(after rest: ArraySlice<Run>) -> String {
        for run in rest where run.zone != .hof && !run.zone.isStairs {
            switch run.zone {
            case .forum, .roomA: return "nav.crossCourtyardForum"
            case .corridorB, .middleB, .roomB: return "nav.crossCourtyardB"
            case .corridorC, .middleC, .roomC: return "nav.crossCourtyardC"
            case .sport: return "nav.crossCourtyardGym"
            case .aula: return "nav.crossCourtyardAula"
            case .outdoor, .parking, .bike: return "nav.crossCourtyardExit"
            default: continue
            }
        }
        // Route ends in a stair house (e.g. a WC there): name the stair house.
        switch rest.first(where: { $0.zone.isStairs })?.zone {
        case .stairsAB: return "nav.goToStairsAB"
        case .stairsAC: return "nav.goToStairsAC"
        case .stairsBSport: return "nav.goToStairsBSport"
        case .stairsCAula: return "nav.goToStairsCAula"
        default: return "nav.goToCourtyard"
        }
    }

    /// Left/right/straight arrow from the heading change between the end of the previous
    /// segment and the start of this one.
    private func turnIcon(previous: [GeoCoord], line: [GeoCoord]) -> String {
        guard previous.count >= 2, line.count >= 2 else { return "arrow.up" }
        let p0 = previous[previous.count - 2], p1 = previous[previous.count - 1]
        let q0 = line[0], q1 = line[1]
        let v1 = ((p1.lon - p0.lon) * kE, (p1.lat - p0.lat) * kN)
        let v2 = ((q1.lon - q0.lon) * kE, (q1.lat - q0.lat) * kN)
        let angle = atan2(v1.0 * v2.1 - v1.1 * v2.0, v1.0 * v2.0 + v1.1 * v2.1) * 180 / .pi
        if angle > 35 { return "arrow.turn.up.left" }
        if angle < -35 { return "arrow.turn.up.right" }
        return "arrow.up"
    }

    private func polylineLength(_ line: [GeoCoord]) -> Double {
        zip(line, line.dropFirst()).reduce(0) { sum, pair in
            sum + hypot((pair.1.lon - pair.0.lon) * kE, (pair.1.lat - pair.0.lat) * kN)
        }
    }
}

/// Binary min-heap of (priority, state) used by the A* search.
private struct MinHeap {
    private var items: [(Float, Int)] = []

    mutating func push(_ priority: Float, _ value: Int) {
        items.append((priority, value))
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard items[i].0 < items[parent].0 else { break }
            items.swapAt(i, parent)
            i = parent
        }
    }

    mutating func pop() -> (Float, Int)? {
        guard !items.isEmpty else { return nil }
        let top = items[0]
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var m = i
                if l < items.count && items[l].0 < items[m].0 { m = l }
                if r < items.count && items[r].0 < items[m].0 { m = r }
                if m == i { break }
                items.swapAt(i, m)
                i = m
            }
        }
        return top
    }
}
