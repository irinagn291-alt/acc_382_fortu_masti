import Foundation

struct Pass {
    let name: String
    let tiger: Int
    let wardens: [Int]
    let rocks: Set<Int>
    let gates: Set<Int>
    let limit: Int
    static let atlas = [
        Pass(name: "Juniper Pass", tiger: 22, wardens: [5, 7, 9], rocks: [11, 13], gates: [0, 4], limit: 12),
        Pass(name: "Copper Steps", tiger: 20, wardens: [3, 7, 13, 17], rocks: [6, 12], gates: [4, 14], limit: 14),
        Pass(name: "Moon Saddle", tiger: 24, wardens: [6, 7, 11, 17], rocks: [8, 16], gates: [0, 10], limit: 14),
        Pass(name: "Cloud Bridge", tiger: 21, wardens: [2, 6, 8, 14], rocks: [7, 12, 18], gates: [0, 4], limit: 13),
        Pass(name: "Salt Ravine", tiger: 19, wardens: [6, 11, 13, 16], rocks: [7, 17], gates: [0, 20], limit: 14),
        Pass(name: "Amber Crown", tiger: 22, wardens: [2, 6, 8, 12, 14], rocks: [11, 17], gates: [0, 4], limit: 16)
    ]
}
struct Step: Equatable { let from: Int; let to: Int; var jumped: Int? = nil }
enum Side: String, Codable { case tiger, wardens }
struct Position: Codable, Equatable {
    var tiger: Int
    var wardens: [Int]
    var side: Side = .tiger
    var turns = 0
    init(_ pass: Pass) { tiger = pass.tiger; wardens = pass.wardens }
    static func linked(_ a: Int, _ b: Int) -> Bool {
        let dx = abs(a % 5 - b % 5), dy = abs(a / 5 - b / 5)
        return dx + dy == 1 || (dx == 1 && dy == 1 && (a % 5 + a / 5).isMultiple(of: 2))
    }
    static let neighbours = (0..<25).map { a in (0..<25).filter { linked(a, $0) } }
    func tigerSteps(in pass: Pass) -> [Step] {
        Self.neighbours[tiger].compactMap { next in
            guard !pass.rocks.contains(next) else { return nil }
            if !wardens.contains(next) { return Step(from: tiger, to: next) }
            let x = 2 * (next % 5) - tiger % 5, y = 2 * (next / 5) - tiger / 5
            guard (0..<5).contains(x), (0..<5).contains(y) else { return nil }
            let landing = y * 5 + x
            guard !wardens.contains(landing), !pass.rocks.contains(landing) else { return nil }
            return Step(from: tiger, to: landing, jumped: next)
        }
    }
    func guards(in pass: Pass) -> [Step] {
        wardens.flatMap { from in
            Self.neighbours[from].compactMap { to in
                guard to != tiger, !wardens.contains(to), !pass.rocks.contains(to), !pass.gates.contains(to) else { return nil }
                return Step(from: from, to: to)
            }
        }
    }
    func outcome(in pass: Pass) -> Side? {
        if pass.gates.contains(tiger) { return .tiger }
        if turns >= pass.limit || (side == .tiger && tigerSteps(in: pass).isEmpty) { return .wardens }
        if side == .wardens && guards(in: pass).isEmpty { return .tiger }
        return nil
    }
    func applying(_ step: Step) -> Position {
        var p = self
        if side == .tiger {
            p.tiger = step.to; p.turns += 1
            if let jumped = step.jumped { p.wardens.removeAll { $0 == jumped } }
            p.side = .wardens
        } else if let i = p.wardens.firstIndex(of: step.from) {
            p.wardens[i] = step.to; p.side = .tiger
        }
        return p
    }
    private func score(in pass: Pass) -> Int {
        if let winner = outcome(in: pass) { return winner == .wardens ? 10000 : -10000 }
        // Evaluate routes with the actual jump rules and current guard placement.
        var frontier = [tiger], seen: Set<Int> = [tiger], distance = 0
        while !frontier.isEmpty && !frontier.contains(where: pass.gates.contains) {
            distance += 1
            frontier = frontier.flatMap { start -> [Int] in
                var test = self; test.tiger = start
                return test.tigerSteps(in: pass).compactMap { seen.insert($0.to).inserted ? $0.to : nil }
            }
        }
        if frontier.isEmpty { distance = 9 }
        return distance * 12 + wardens.count * 6 - tigerSteps(in: pass).count * 2
    }
    func reply(in pass: Pass) -> Step? {
        var best: Step?, bestScore = Int.min
        for move in guards(in: pass) {
            let defended = applying(move)
            var score = defended.score(in: pass)
            if defended.outcome(in: pass) == nil {
                var worst = Int.max
                for answer in defended.tigerSteps(in: pass) {
                    worst = min(worst, defended.applying(answer).score(in: pass))
                    if worst < bestScore { break }
                }
                score = worst
            }
            if score > bestScore { best = move; bestScore = score }
        }
        return best
    }
}
struct Crossing: Codable {
    var map: Int
    var solo: Bool
    var position: Position
    var history: [Position] = []
    init(map: Int = 0, solo: Bool = true) {
        self.map = map; self.solo = solo; position = Position(Pass.atlas[map])
    }
    var pass: Pass { Pass.atlas[map] }
    var winner: Side? { position.outcome(in: pass) }
    var choices: [Step] { position.side == .tiger ? position.tigerSteps(in: pass) : position.guards(in: pass) }
    mutating func play(_ move: Step) {
        guard winner == nil, choices.contains(move) else { return }
        history.append(position)
        position = position.applying(move)
        if solo && winner == nil && position.side == .wardens, let response = position.reply(in: pass) {
            position = position.applying(response)
        }
    }
    mutating func undo() { if let last = history.popLast() { position = last } }
}
