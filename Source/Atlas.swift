import SwiftUI

struct PassAtlas: View {
    @ObservedObject var log: MatchBook
    var begin: (Int, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var map: Int
    @State private var solo: Bool
    @State private var confirm = false
    init(log: MatchBook, begin: @escaping (Int,Bool) -> Void) {
        self.log = log; self.begin = begin
        _map = State(initialValue: log.book.game.map)
        _solo = State(initialValue: log.book.game.solo)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Players", selection: $solo) {
                        Text("Solo").tag(true); Text("Two players").tag(false)
                    }.pickerStyle(.segmented)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 12) {
                        ForEach(Pass.atlas.indices, id: \.self) { i in
                            let p = Pass.atlas[i]
                            Button { map = i } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    MiniPass(pass: p).frame(height: 76)
                                    Text(verbatim: phrase(p.name)).font(.system(.headline, design: .serif))
                                    if let best = log.book.soloBests[i] {
                                        Label("\(best)", systemImage: "laurel.leading").font(.caption.monospacedDigit())
                                    } else {
                                        Text(verbatim: "\(phrase("Move limit"))  \(p.limit)").font(.caption)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(i == map ? Color.orange : .clear, lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityIdentifier("pass\(i)")
                        }
                    }
                    Text(verbatim: phrase(solo ? "You guide the tiger. The wardens respond on this device." : "Share the board. One player guides the tiger and one commands the wardens."))
                        .font(.subheadline)
                    Button {
                        if log.book.game.position.turns > 0 && log.book.game.winner == nil { confirm = true }
                        else { begin(map, solo) }
                    } label: { Text("Begin crossing").bold().frame(maxWidth: .infinity).padding(6) }
                        .buttonStyle(.borderedProminent).tint(.orange).foregroundStyle(.black).accessibilityIdentifier("begin")
                }.padding()
            }.navigationTitle("Pass atlas")
            .toolbar { Button("Done") { dismiss() } }
            .confirmationDialog("Replace the current crossing?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Begin crossing", role: .destructive) { begin(map, solo) }; Button("Cancel", role: .cancel) {}
            }
        }.preferredColorScheme(.dark)
    }
}

struct MiniPass: View {
    let pass: Pass
    var body: some View {
        Canvas { ctx, s in
            let step = min(s.width,s.height)*0.205
            func pos(_ n: Int) -> CGPoint { .init(x: s.width/2 + CGFloat(n%5-2)*step, y: s.height/2 + CGFloat(n/5-2)*step) }
            for n in 0..<25 where !pass.rocks.contains(n) {
                let c = pos(n)
                for next in Position.neighbours[n] where next > n && !pass.rocks.contains(next) {
                    var line = Path(); line.move(to: c); line.addLine(to: pos(next))
                    ctx.stroke(line, with: .color(.white.opacity(0.28)), lineWidth: 1)
                }
                let isTiger = n == pass.tiger, isGuard = pass.wardens.contains(n), gate = pass.gates.contains(n)
                let r = step * (isTiger || isGuard || gate ? 0.25 : 0.09)
                ctx.fill(Path(ellipseIn: .init(x: c.x-r, y:c.y-r,width:2*r,height:2*r)), with: .color(isTiger || gate ? .orange : .white.opacity(isGuard ? 1 : 0.4)))
            }
        }.accessibilityHidden(true)
    }
}

struct FieldRules: View {
    @Environment(\.dismiss) private var dismiss
    let rules = [
        ("pawprint.fill", "Tiger", "Follow a line to an empty point. Leap over one adjacent warden along the same line to remove it. Land on an empty point."),
        ("diamond.fill", "Golden gates", "Reach either golden diamond before the move limit. Your last move can win. Crosses mark impassable rock."),
        ("mountain.2.fill", "Wardens", "Move one warden by one line after each tiger move. Wardens cannot enter the gates. Trap the tiger or defend until the limit."),
        ("arrow.uturn.backward", "At the table", "Lit rings show legal destinations. In solo play, Undo takes back your move and the reply. Your best solo escape is saved for each pass.")
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Image("RidgePainting").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8)).frame(maxHeight: 240)
                    ForEach(rules, id: \.0) { rule in
                        HStack(alignment:.top,spacing:13) {
                            Image(systemName:rule.0).frame(width:26).foregroundStyle(.orange)
                            VStack(alignment:.leading,spacing:5) {
                                Text(verbatim:phrase(rule.1)).font(.system(.title3,design:.serif).bold())
                                Text(verbatim:phrase(rule.2)).font(.body)
                            }
                        }
                    }
                }.padding().frame(maxWidth:620)
            }.navigationTitle("Field rules").toolbar { Button("Done") { dismiss() } }
        }.preferredColorScheme(.dark)
    }
}
