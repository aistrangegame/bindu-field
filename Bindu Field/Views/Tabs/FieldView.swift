import SwiftUI
import UIKit

struct FieldView: View {
    @State private var store = PlayerStore.shared
    @State private var catalog = CatalogStore.shared
    @State private var sessionStore = SessionStore.shared
    @State private var committedRotY: Double = 0
    @State private var dragRotY: Double = 0
    @State private var dragStart: CGPoint?
    @State private var stateFilter: BrainwaveState? = nil   // nil = "all"

    /// O22: long-pressing the central Bindu opens the Oracle, but the
    /// gesture has no visual hint. Show a one-time serif tooltip below
    /// the Bindu for new users; dismiss on tap or after the gesture is
    /// invoked.
    @State private var showOracleHint: Bool = !UserDefaults.standard.bool(forKey: "binduFirstLaunch.oracleHintSeen")

    @Environment(\.binduTheme) private var theme

    private func dismissOracleHint() {
        guard showOracleHint else { return }
        UserDefaults.standard.set(true, forKey: "binduFirstLaunch.oracleHintSeen")
        withAnimation(.easeOut(duration: 0.4)) { showOracleHint = false }
    }

    private var filteredTracks: [Track] {
        guard let filter = stateFilter else { return catalog.tracks }
        return catalog.tracks.filter { $0.state == filter }
    }

    /// Track IDs that appear in saved session history. Drives the
    /// "you've been here" inner glow + full-opacity render.
    private var playedTrackIDs: Set<Int> {
        Set(
            sessionStore.sessions
                .filter { $0.type == .track }
                .compactMap { Int($0.sourceID) }
        )
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title
                VStack(spacing: 4) {
                    Text("Field")
                        .font(.system(size: 24, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                    Text("the constellation")
                        .font(.system(size: 11))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle)
                }
                .padding(.top, 16)

                // Filter chip row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(label: "all", isSelected: stateFilter == nil) {
                            withAnimation(.easeInOut(duration: 0.4)) { stateFilter = nil }
                        }
                        Chip(label: "delta", isSelected: stateFilter == .delta) {
                            withAnimation(.easeInOut(duration: 0.4)) { stateFilter = .delta }
                        }
                        Chip(label: "theta", isSelected: stateFilter == .theta) {
                            withAnimation(.easeInOut(duration: 0.4)) { stateFilter = .theta }
                        }
                        Chip(label: "theta-alpha", isSelected: stateFilter == .thetaAlpha) {
                            withAnimation(.easeInOut(duration: 0.4)) { stateFilter = .thetaAlpha }
                        }
                        Chip(label: "alpha", isSelected: stateFilter == .alpha) {
                            withAnimation(.easeInOut(duration: 0.4)) { stateFilter = .alpha }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Constellation canvas (or loading state while catalog is empty)
                GeometryReader { geo in
                    TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let autoRot = t * 0.08   // slow auto-rotation, radians/sec
                        let rotY = autoRot + committedRotY + dragRotY

                        Canvas { ctx, size in
                            let positions = computePositions(rotY: rotY, size: size)
                            let played = playedTrackIDs

                            // Layer C — same-element pair lines on the front hemisphere.
                            // depth is rzz in [-1, +1]; normalize so 0 = front, 1 = back.
                            let frontByElement: [String: [Projection]] = Dictionary(
                                grouping: positions.filter { (($0.depth + 1.0) * 0.5) < 0.5 },
                                by: { $0.track.element }
                            )
                            for (_, group) in frontByElement where group.count >= 2 {
                                guard let first = group.first else { continue }
                                let strokeColor = Color.bindu(element: first.track.element).opacity(0.07)
                                for i in 0..<group.count {
                                    for j in (i + 1)..<group.count {
                                        var path = Path()
                                        path.move(to: group[i].screen)
                                        path.addLine(to: group[j].screen)
                                        ctx.stroke(path, with: .color(strokeColor), lineWidth: 0.5)
                                    }
                                }
                            }

                            // Sort back-first so front orbs paint last.
                            let sorted = positions.sorted { $0.depth > $1.depth }

                            for proj in sorted {
                                let isPlaying = (store.currentTrack?.id == proj.track.id)
                                let isPlayed = played.contains(proj.track.id)

                                let depthNorm = (proj.depth + 1.0) * 0.5     // 0 front .. 1 back
                                let fogFactor = 1.0 - (depthNorm * 0.5)      // 1.0 front .. 0.5 back
                                let sizeScale = 1.0 - (depthNorm * 0.2)      // 1.0 front .. 0.8 back

                                let baseRadius = 9.0 * sizeScale
                                let radius = isPlaying ? baseRadius * 1.8 : baseRadius

                                let color = Color.bindu(element: proj.track.element)
                                let baseOpacity: Double = isPlaying ? 1.0 : (isPlayed ? 1.0 : 0.55)
                                let foggedOpacity = baseOpacity * fogFactor

                                // Played mark — soft inner glow ring beneath the orb.
                                if isPlayed && !isPlaying {
                                    let ringR = radius * 1.4
                                    let ringRect = CGRect(
                                        x: proj.screen.x - ringR,
                                        y: proj.screen.y - ringR,
                                        width: ringR * 2,
                                        height: ringR * 2
                                    )
                                    ctx.fill(Path(ellipseIn: ringRect), with: .color(color.opacity(0.25 * fogFactor)))
                                }

                                // Playing orb — original pulse rings (kept verbatim).
                                if isPlaying {
                                    let pulse = sin(t * 4) * 0.5 + 0.5
                                    for ringIdx in 1...3 {
                                        let ringR = radius + CGFloat(ringIdx) * 8 + CGFloat(pulse * 4)
                                        let ringAlpha = (0.4 / Double(ringIdx)) * (1 - pulse)
                                        ctx.stroke(
                                            Path(ellipseIn: CGRect(
                                                x: proj.screen.x - ringR,
                                                y: proj.screen.y - ringR,
                                                width: ringR * 2,
                                                height: ringR * 2
                                            )),
                                            with: .color(color.opacity(ringAlpha)),
                                            lineWidth: 1.5
                                        )
                                    }
                                }

                                // The orb itself.
                                let rect = CGRect(
                                    x: proj.screen.x - radius,
                                    y: proj.screen.y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                )
                                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(foggedOpacity)))
                                ctx.stroke(
                                    Path(ellipseIn: rect),
                                    with: .color(color.opacity(min(foggedOpacity * 1.2, 1.0))),
                                    lineWidth: 0.8
                                )
                            }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStart == nil { dragStart = value.startLocation }
                                let dx = value.translation.width
                                dragRotY = Double(dx) * 0.01
                            }
                            .onEnded { _ in
                                committedRotY += dragRotY
                                dragRotY = 0
                                dragStart = nil
                            }
                    )
                    .onTapGesture { location in
                        handleTap(at: location, rotY: lastRotY(in: geo.size), size: geo.size)
                    }
                    .overlay(alignment: .center) {
                        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            // Slow breath: ~0.1 Hz (one full cycle per ~10 seconds)
                            let pulse = (sin(t * 0.628) + 1) * 0.5  // 0..1
                            let scale = 0.85 + CGFloat(pulse) * 0.30  // 0.85..1.15

                            ZStack {
                                // Glow
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(red: 0.898, green: 0.322, blue: 0.306).opacity(0.4 * (0.7 + pulse * 0.3)),
                                                Color(red: 0.898, green: 0.322, blue: 0.306).opacity(0)
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 36
                                        )
                                    )
                                    .frame(width: 72, height: 72)

                                // Core
                                Circle()
                                    .fill(Color(red: 0.898, green: 0.322, blue: 0.306))
                                    .frame(width: 14, height: 14)
                                    .shadow(color: Color(red: 0.898, green: 0.322, blue: 0.306).opacity(0.6), radius: 6)
                            }
                            .scaleEffect(scale)
                            .contentShape(Circle().size(width: 80, height: 80))  // larger tap target than visual
                        }
                        .onLongPressGesture(minimumDuration: 0.6) {
                            // Tap-and-hold → open Oracle. Oracle's tag
                            // shifted from 1 to 2 when the Map became
                            // the front door (Session B).
                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                            haptic.impactOccurred()
                            dismissOracleHint()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                NavigationStore.shared.selectedTab = 2
                            }
                        }
                    }
                    .overlay(alignment: .center) {
                        // O22: first-launch tooltip below the central Bindu.
                        if showOracleHint {
                            Text("hold for Oracle")
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundColor(theme.muted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.72))
                                        .overlay(Capsule().stroke(theme.muted.opacity(0.25), lineWidth: 1))
                                )
                                .offset(y: 70)
                                .onTapGesture { dismissOracleHint() }
                                .transition(.opacity)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if catalog.tracks.isEmpty && catalog.isLoading {
                            HStack(spacing: 10) {
                                ProgressView().tint(theme.muted)
                                Text("loading the field…")
                                    .font(.system(size: 12, design: .serif))
                                    .italic()
                                    .foregroundColor(theme.muted)
                            }
                            .padding(.bottom, 24)
                        } else if catalog.tracks.isEmpty, let err = catalog.loadError {
                            Text(err)
                                .font(.system(size: 11, design: .serif))
                                .italic()
                                .foregroundColor(theme.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sphere math

    struct Projection {
        let track: Track
        let screen: CGPoint
        let depth: Double   // z value, -1 (front) to 1 (back)
        let scale: Double   // perspective scale factor, 0..1
    }

    private func computePositions(rotY: Double, size: CGSize) -> [Projection] {
        let tracks = filteredTracks
        let total = tracks.count
        let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
        let minDim = Double(min(size.width, size.height))

        return tracks.enumerated().map { (i, track) in
            let y: Double
            if total <= 1 {
                y = 0
            } else {
                y = 1.0 - (Double(i) / Double(total - 1)) * 2.0
            }
            let r = sqrt(max(0, 1 - y * y))
            let theta = goldenAngle * Double(i)
            let px = cos(theta) * r
            let pz = sin(theta) * r
            let rx = px * cos(rotY) - pz * sin(rotY)
            let rzz = px * sin(rotY) + pz * cos(rotY)
            let fov = 460.0
            let sc = fov / (fov + rzz * 140.0)
            let sx = Double(size.width) / 2 + rx * minDim * 0.44 * sc
            let sy = Double(size.height) * 0.45 + y * minDim * 0.46 * sc
            return Projection(
                track: track,
                screen: CGPoint(x: sx, y: sy),
                depth: rzz,
                scale: sc
            )
        }
    }

    private func lastRotY(in size: CGSize) -> Double {
        // Approximate current rotation for hit-testing
        let t = Date().timeIntervalSinceReferenceDate
        return t * 0.08 + committedRotY + dragRotY
    }

    private func handleTap(at location: CGPoint, rotY: Double, size: CGSize) {
        let positions = computePositions(rotY: rotY, size: size)
        let candidates = positions.filter { $0.depth < 0.7 }
        let threshold: CGFloat = 36
        var best: (proj: Projection, dist: CGFloat)? = nil
        for p in candidates {
            let dx = p.screen.x - location.x
            let dy = p.screen.y - location.y
            let dist = sqrt(dx*dx + dy*dy)
            if dist < threshold {
                if best == nil || dist < best!.dist {
                    best = (p, dist)
                }
            }
        }
        if let hit = best {
            store.play(hit.proj.track)
        }
    }

}
