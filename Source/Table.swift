import SwiftUI

func phrase(_ key: String) -> String { NSLocalizedString(key, comment: "") }
private let pine = Color(red: 0.045, green: 0.134, blue: 0.143)
private let felt = Color(red: 0.094, green: 0.205, blue: 0.206)
private let ivory = Color(red: 0.97, green: 0.92, blue: 0.77)
private let brass = Color(red: 0.96, green: 0.72, blue: 0.35)

@MainActor final class MatchBook: ObservableObject {
    struct Book: Codable { var game = Crossing(); var soloBests: [Int: Int] = [:] }
    @Published private(set) var book = Book()
    @Published var problem = false
    private let url = URL.applicationSupportDirectory.appending(path: "ridge-table.json")
    init() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let saved = try JSONDecoder().decode(Book.self, from: Data(contentsOf: url))
            guard Pass.atlas.indices.contains(saved.game.map), (0..<25).contains(saved.game.position.tiger),
                  saved.game.position.wardens.allSatisfy({ (0..<25).contains($0) }) else { problem = true; return }
            book = saved
        } catch { problem = true }
    }
    func play(_ step: Step) {
        book.game.play(step)
        let g = book.game
        if g.solo && g.winner == .tiger { book.soloBests[g.map] = min(book.soloBests[g.map] ?? Int.max, g.position.turns) }
        save()
    }
    func undo() { guard book.game.winner == nil else { return }; book.game.undo(); save() }
    func start(_ map: Int, solo: Bool) { book.game = Crossing(map: map, solo: solo); save() }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(book).write(to: url, options: .atomic)
        } catch { problem = true }
    }
}

@main struct RidgeWardApp: App {
    @StateObject private var log = MatchBook()
    var body: some Scene { WindowGroup { GameTable(log: log) } }
}

struct GameTable: View {
    @ObservedObject var log: MatchBook
    @Environment(\.horizontalSizeClass) private var size
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selection: Int?
    @State private var atlas = false
    @State private var guide = false
    private var game: Crossing { log.book.game }
    private var source: Int? { game.position.side == .tiger ? game.position.tiger : selection }
    private var moves: [Step] { game.winner == nil ? game.choices.filter { $0.from == source } : [] }
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Fortu Masti").font(.system(.title, design: .serif).weight(.bold))
                        Spacer()
                        Button { guide = true } label: { Image(systemName: "book.pages").frame(width: 44, height: 44) }
                            .accessibilityLabel(Text("Field rules")).accessibilityIdentifier("rules")
                        Button { atlas = true } label: { Image(systemName: "map").frame(width: 44, height: 44) }
                            .accessibilityLabel(Text("Pass atlas")).accessibilityIdentifier("atlas")
                    }
                    if size == .regular && geo.size.width > geo.size.height && geo.size.width > 680 && !typeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: 14) { passHeader(tall: true); controls }.frame(width: min(360,geo.size.width*0.36))
                            board
                        }
                    } else if size == .regular && geo.size.width > 680 {
                        passHeader(tall: false).frame(height: min(230, geo.size.height * 0.15))
                        board.frame(maxWidth: min(geo.size.width - 52, geo.size.height * 0.64))
                            .frame(maxWidth: .infinity)
                        controls
                    } else { passHeader(tall: false); board; controls }
                }.padding(.horizontal, size == .regular ? 26 : 16).padding(.top, 4).padding(.bottom, 20)
                .frame(maxWidth: 1160).frame(maxWidth: .infinity)
            }
        }
        .background(pine).foregroundStyle(ivory).tint(brass).preferredColorScheme(.dark)
        .sheet(isPresented: $guide) { FieldRules() }
        .sheet(isPresented: $atlas) {
            PassAtlas(log: log) { map, solo in log.start(map, solo: solo); selection = nil; atlas = false }
        }
        .alert("The match could not be opened or saved.", isPresented: $log.problem) { Button("OK") {} }
    }
    private func passHeader(tall: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { g in Image("RidgePainting").resizable().scaledToFill()
                .frame(width: g.size.width, height: g.size.height, alignment: .center).clipped() }
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: phrase(game.solo ? "Solo expedition" : "Two at the table").uppercased())
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(brass)
                Text(verbatim: phrase(game.pass.name)).font(.system(.title, design: .serif).weight(.bold))
            }.padding(14)
        }.frame(minHeight: tall ? 300 : 112).clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(false)
    }
    private var board: some View {
        BoardView(game: game, selected: source, targets: Set(moves.map(\.to)), tap: tap)
            .aspectRatio(1, contentMode: .fit)
    }
    private func tap(_ index: Int) {
        guard game.winner == nil else { return }
        if let move = moves.first(where: { $0.to == index }) { log.play(move); selection = nil }
        else if game.position.side == .wardens && game.position.wardens.contains(index) { selection = index }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: phrase(game.winner.map { $0 == .tiger ? "Tiger escaped" : "Pass defended" } ??
                    (game.position.side == .tiger ? "Tiger to move" : "Wardens to move")))
                    .font(.system(.title2, design: .serif).bold()).accessibilityIdentifier("turn")
                Spacer()
                Text("\(game.position.turns) / \(game.pass.limit)").font(.system(.subheadline, design: .monospaced))
                    .accessibilityIdentifier("counter")
            }
            Text(verbatim: phrase(game.winner == nil ? (game.position.side == .tiger ? "Reach a golden gate. Tap a lit point to move." : "Choose an ivory warden, then a lit point.") :
                                    (game.winner == .tiger ? "The ridge is open. Explore another pass." : "The wardens held the ridge. Try a different route.")))
                .font(.subheadline).foregroundStyle(ivory.opacity(0.80))
            HStack {
                Button { log.undo(); selection = nil } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(game.history.isEmpty || game.winner != nil).accessibilityIdentifier("undo")
                Spacer()
                Button { atlas = true } label: { Label("New crossing", systemImage: "flag.checkered") }
                    .buttonStyle(.bordered).accessibilityIdentifier("new")
            }
        }.padding(14).background(felt, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BoardView: View {
    let game: Crossing
    let selected: Int?
    let targets: Set<Int>
    let tap: (Int) -> Void
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height), pad = side * 0.10, pitch = (side - pad * 2) / 4
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [felt, pine, felt], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 11).strokeBorder(brass.opacity(0.65), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 8).inset(by: 5).strokeBorder(brass.opacity(0.28), lineWidth: 1)
                Canvas { ctx, _ in
                    func spot(_ n: Int) -> CGPoint { .init(x: pad + CGFloat(n % 5)*pitch, y: pad + CGFloat(n / 5)*pitch) }
                    for i in 0..<25 {
                        for j in Position.neighbours[i] where j > i {
                            let blocked = game.pass.rocks.contains(i) || game.pass.rocks.contains(j)
                            var p = Path(); p.move(to: spot(i)); p.addLine(to: spot(j))
                            ctx.stroke(p, with: .color(brass.opacity(blocked ? 0.16 : 0.65)),
                                       style: StrokeStyle(lineWidth: blocked ? 1 : 1.5, dash: blocked ? [2, 4] : []))
                        }
                    }
                }.accessibilityHidden(true)
                ForEach(0..<25, id: \.self) { n in
                    let tiger = n == game.position.tiger, guardHere = game.position.wardens.contains(n)
                    let gate = game.pass.gates.contains(n), rock = game.pass.rocks.contains(n)
                    let symbol = tiger ? "pawprint.fill" : guardHere ? "mountain.2.fill" : gate ? "diamond.fill" : rock ? "xmark" : "circle.fill"
                    let occupied = tiger || guardHere
                    Button { tap(n) } label: {
                        ZStack {
                            if occupied {
                                Circle().fill(LinearGradient(colors: tiger ? [brass, Color.orange] : [ivory, Color(red: 0.69, green: 0.67, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: .black.opacity(0.55), radius: 2, y: 3)
                                Circle().inset(by: 3).stroke(pine.opacity(0.55), lineWidth: 1)
                            } else if targets.contains(n) {
                                Circle().fill(brass.opacity(0.22)); Circle().stroke(brass, lineWidth: 1.5)
                            }
                            if n == selected { Circle().inset(by: -3).stroke(brass, lineWidth: 2) }
                            Image(systemName: symbol).font(.system(size: pitch * (occupied ? 0.29 : gate || rock ? 0.20 : 0.09), weight: .bold))
                                .foregroundStyle(occupied ? pine : gate || targets.contains(n) ? brass : ivory.opacity(rock ? 0.34 : 0.58))
                        }.frame(width: pitch*0.60, height: pitch*0.60)
                        .frame(width: pitch*0.90, height: pitch*0.90).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(Character(UnicodeScalar(65+n%5)!))\(5-n/5) · \(phrase(tiger ? "Tiger" : guardHere ? "Warden" : gate ? "Gate" : rock ? "Rock" : "Open point"))"))
                    .accessibilityIdentifier("point\(n)")
                    .position(x: pad + CGFloat(n % 5)*pitch, y: pad + CGFloat(n / 5)*pitch)
                }
            }
        }.environment(\.layoutDirection, .leftToRight)
    }
}
