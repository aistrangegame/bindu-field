import SwiftUI

/// The Map. The front door of the app — 33 nodes on a 393 × 780 design
/// canvas scaled to the device, with element-curve connections and
/// three render states per node (locked / available / danced).
///
/// Tapping a composed node raises `MapDetailSheet`.
struct MapView: View {
    @State private var journey = ChakraJourneyStore.shared
    @State private var catalog = CatalogStore.shared
    @State private var player = PlayerStore.shared
    @State private var selectedID: String? = nil
    @State private var showSheet: Bool = false

    @Environment(\.binduTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color(hex: "#020208").ignoresSafeArea()

                let scale = scale(for: geo.size)
                let offsetXY = offset(for: geo.size, scale: scale)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    Canvas { gc, _ in
                        // Connections first, nodes on top.
                        drawConnections(in: gc, scale: scale, offset: offsetXY)
                        drawNodes(in: gc, t: t, scale: scale, offset: offsetXY)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            handleTap(at: value.location, scale: scale, offset: offsetXY)
                        }
                )

                // Title block — anchored top, very subtle.
                VStack(spacing: 6) {
                    Text("THE MAP")
                        .font(.system(size: 9, weight: .light))
                        .tracking(3.5)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.text.opacity(0.55))
                    Text("a body has thirty-three doors")
                        .font(.system(size: 12, weight: .light, design: .serif).italic())
                        .foregroundStyle(theme.text.opacity(0.62))
                }
                .padding(.top, 18)
            }
            .sheet(isPresented: $showSheet, onDismiss: { selectedID = nil }) {
                if let id = selectedID, let node = ChakraRegistry.node(id: id) {
                    MapDetailSheet(
                        chakra: node,
                        state: journey.state(for: node),
                        track: trackForChakra(node),
                        onEnter: { track in
                            showSheet = false
                            player.play(track)
                        }
                    )
                    .presentationDetents([.fraction(0.55)])
                    .presentationBackground(Color(red: 12/255, green: 10/255, blue: 18/255))
                }
            }
        }
    }

    // MARK: — Layout

    /// Scale ratio so the design canvas (393 × 780) fits the device while
    /// preserving aspect. Uses the smaller of the two ratios; the larger
    /// dimension gets a centered margin.
    private func scale(for size: CGSize) -> CGFloat {
        let sx = size.width / ChakraRegistry.designCanvasWidth
        let sy = size.height / ChakraRegistry.designCanvasHeight
        return min(sx, sy)
    }

    private func offset(for size: CGSize, scale: CGFloat) -> CGPoint {
        let scaledW = ChakraRegistry.designCanvasWidth * scale
        let scaledH = ChakraRegistry.designCanvasHeight * scale
        return CGPoint(
            x: (size.width - scaledW) / 2,
            y: (size.height - scaledH) / 2
        )
    }

    private func devicePoint(for node: ChakraNode, scale: CGFloat, offset: CGPoint) -> CGPoint {
        CGPoint(
            x: offset.x + node.canvasX * scale,
            y: offset.y + node.canvasY * scale
        )
    }

    // MARK: — Drawing

    private func drawConnections(in gc: GraphicsContext, scale: CGFloat, offset: CGPoint) {
        for (a, b) in ChakraRegistry.connections {
            guard let na = ChakraRegistry.node(id: a),
                  let nb = ChakraRegistry.node(id: b) else { continue }
            let pa = devicePoint(for: na, scale: scale, offset: offset)
            let pb = devicePoint(for: nb, scale: scale, offset: offset)

            let aLit = journey.state(for: na) != .locked
            let bLit = journey.state(for: nb) != .locked
            let bothLit = aLit && bLit
            let eitherLit = aLit || bLit

            let opacity = bothLit ? 0.18 : eitherLit ? 0.09 : 0.045
            let lineWidth: CGFloat = bothLit ? 0.7 : 0.5

            // Slight midpoint bow for an organic curve.
            let mx = (pa.x + pb.x) / 2
            let my = (pa.y + pb.y) / 2
            let dx = pb.x - pa.x
            let dy = pb.y - pa.y
            let len = max(0.001, sqrt(dx * dx + dy * dy))
            let curvature: CGFloat = min(len * 0.12, 18)
            let nx = -dy / len * curvature
            let ny =  dx / len * curvature

            var path = Path()
            path.move(to: pa)
            path.addQuadCurve(to: pb, control: CGPoint(x: mx + nx, y: my + ny))

            if bothLit {
                let stops = Gradient(stops: [
                    .init(
                        color: Color(hue: na.hue / 360, saturation: 0.50, brightness: 0.65).opacity(opacity),
                        location: 0
                    ),
                    .init(
                        color: Color(hue: nb.hue / 360, saturation: 0.50, brightness: 0.65).opacity(opacity),
                        location: 1
                    ),
                ])
                gc.stroke(
                    path,
                    with: .linearGradient(stops, startPoint: pa, endPoint: pb),
                    lineWidth: lineWidth
                )
            } else {
                gc.stroke(
                    path,
                    with: .color(Color(hex: "#F5E2D6").opacity(opacity)),
                    lineWidth: lineWidth
                )
            }
        }
    }

    private func drawNodes(in gc: GraphicsContext, t: Double, scale: CGFloat, offset: CGPoint) {
        let phase = t
        for node in ChakraRegistry.all {
            let p = devicePoint(for: node, scale: scale, offset: offset)
            let state = journey.state(for: node)
            let isSelected = selectedID == node.id

            switch state {
            case .locked:
                drawLockedNode(in: gc, at: p, tier: node.tier)
            case .available:
                drawLitNode(in: gc, at: p, hue: node.hue, phase: phase,
                            isDanced: false, isSelected: isSelected)
            case .danced:
                drawLitNode(in: gc, at: p, hue: node.hue, phase: phase,
                            isDanced: true, isSelected: isSelected)
            }
        }
    }

    private func drawLockedNode(in gc: GraphicsContext, at p: CGPoint, tier: Int) {
        let r: CGFloat
        switch tier {
        case 2: r = 2.8
        case 3: r = 2.2
        default: r = 2.5
        }
        gc.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
            with: .color(Color(hex: "#F5E2D6").opacity(0.18))
        )
    }

    private func drawLitNode(
        in gc: GraphicsContext,
        at p: CGPoint,
        hue: Double,
        phase: Double,
        isDanced: Bool,
        isSelected: Bool
    ) {
        let baseR: CGFloat = isDanced ? 11 : 9
        let r = baseR
        let breathe = 0.6 + 0.4 * sin(
            phase * (isDanced ? 0.8 : 1.1) + (p.x + p.y) * 0.005
        )

        // Outer aura
        let auraR = isSelected ? r * 3.5 : r * 2.8
        let auraAlpha = isDanced ? 0.28 * breathe : 0.20 * breathe
        let aura = Gradient(stops: [
            .init(color: Color(hue: hue / 360, saturation: 0.60, brightness: 0.68).opacity(auraAlpha), location: 0),
            .init(color: Color(hue: hue / 360, saturation: 0.55, brightness: 0.65).opacity(auraAlpha * 0.5), location: 0.4),
            .init(color: Color(hue: hue / 360, saturation: 0.50, brightness: 0.62).opacity(0), location: 1),
        ])
        gc.fill(
            Path(ellipseIn: CGRect(x: p.x - auraR, y: p.y - auraR, width: auraR * 2, height: auraR * 2)),
            with: .radialGradient(aura, center: p, startRadius: 0, endRadius: auraR)
        )

        // Danced orbit rings
        if isDanced {
            let r1 = r + 5 + breathe * 2
            gc.stroke(
                Path(ellipseIn: CGRect(x: p.x - r1, y: p.y - r1, width: r1 * 2, height: r1 * 2)),
                with: .color(Color(hue: hue / 360, saturation: 0.55, brightness: 0.68).opacity(0.25 * breathe)),
                lineWidth: 0.8
            )
            let r2 = r + 9 + breathe
            gc.stroke(
                Path(ellipseIn: CGRect(x: p.x - r2, y: p.y - r2, width: r2 * 2, height: r2 * 2)),
                with: .color(Color(hue: hue / 360, saturation: 0.50, brightness: 0.65).opacity(0.12 * breathe)),
                lineWidth: 0.5
            )
        }

        // Selection highlight
        if isSelected {
            let sr = r + 7
            gc.stroke(
                Path(ellipseIn: CGRect(x: p.x - sr, y: p.y - sr, width: sr * 2, height: sr * 2)),
                with: .color(Color(hue: hue / 360, saturation: 0.65, brightness: 0.75).opacity(0.55)),
                lineWidth: 1
            )
        }

        // Core dot — radial gradient
        let core = Gradient(stops: [
            .init(color: Color(hue: hue / 360, saturation: 0.70, brightness: 0.82), location: 0),
            .init(color: Color(hue: hue / 360, saturation: 0.60, brightness: 0.70), location: 0.5),
            .init(color: Color(hue: hue / 360, saturation: 0.55, brightness: 0.58), location: 1),
        ])
        gc.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                core,
                center: CGPoint(x: p.x - r * 0.25, y: p.y - r * 0.25),
                startRadius: 0,
                endRadius: r
            )
        )

        // Inner shine
        let sr = r * 0.3
        gc.fill(
            Path(ellipseIn: CGRect(x: p.x - r * 0.28 - sr, y: p.y - r * 0.28 - sr, width: sr * 2, height: sr * 2)),
            with: .color(Color.white.opacity(0.25))
        )
    }

    // MARK: — Tap detection

    /// Pick the nearest lit (or locked-but-detectable) node within a
    /// reasonable hit radius. Locked nodes are detectable too — the sheet
    /// surfaces a "not yet composed" copy, which makes the locked dots
    /// feel like part of the map rather than scenery.
    private func handleTap(at point: CGPoint, scale: CGFloat, offset: CGPoint) {
        var best: (id: String, dist: CGFloat) = ("", .infinity)
        for node in ChakraRegistry.all {
            let p = devicePoint(for: node, scale: scale, offset: offset)
            let dx = point.x - p.x
            let dy = point.y - p.y
            let d = sqrt(dx * dx + dy * dy)
            if d < best.dist { best = (node.id, d) }
        }
        // Hit-radius is the lit-node aura radius. Locked nodes get a
        // tighter hit (you have to mean it).
        guard let node = ChakraRegistry.node(id: best.id) else { return }
        let state = journey.state(for: node)
        let hitRadius: CGFloat = state == .locked ? 12 : 28
        if best.dist <= hitRadius {
            selectedID = best.id
            showSheet = true
        }
    }

    // MARK: — Catalog lookup

    /// Find the Track whose `chakra` matches this node (case-insensitive
    /// match against the chakra name). Returns nil for chakras that have
    /// no authored dance — the sheet handles that copy.
    private func trackForChakra(_ chakra: ChakraNode) -> Track? {
        let target = chakra.name.lowercased()
        return catalog.tracks.first {
            ($0.chakra?.rawValue.lowercased() ?? "") == target
        }
    }
}
