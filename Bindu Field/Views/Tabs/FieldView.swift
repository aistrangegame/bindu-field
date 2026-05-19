import SwiftUI
import UIKit

struct FieldView: View {
    @State private var store = PlayerStore.shared
    @State private var committedRotY: Double = 0
    @State private var dragRotY: Double = 0
    @State private var dragStart: CGPoint?
    @State private var stateFilter: BrainwaveState? = nil   // nil = "all"

    private let theme = ThemeData.void

    private var filteredTracks: [Track] {
        guard let filter = stateFilter else { return TrackData.all }
        return TrackData.all.filter { $0.state == filter }
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

                // Constellation canvas
                GeometryReader { geo in
                    TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let autoRot = t * 0.08   // slow auto-rotation, radians/sec
                        let rotY = autoRot + committedRotY + dragRotY

                        Canvas { ctx, size in
                            let positions = computePositions(rotY: rotY, size: size)

                            // Sort by depth (z) so back orbs render first
                            let sorted = positions.sorted { $0.depth < $1.depth }

                            for proj in sorted {
                                let isPlaying = (store.currentTrack?.id == proj.track.id)
                                let baseRadius = 3.5 + 5.5 * proj.scale
                                let radius = isPlaying ? baseRadius * 1.8 : baseRadius

                                let color = Color.bindu(element: proj.track.element.rawValue)
                                let alpha = 0.3 + 0.7 * proj.scale  // depth fading

                                // Active orb pulse
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

                                // The orb
                                let rect = CGRect(
                                    x: proj.screen.x - radius,
                                    y: proj.screen.y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                )
                                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                                ctx.stroke(Path(ellipseIn: rect), with: .color(color.opacity(alpha * 1.2)), lineWidth: 0.8)
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
                            // Tap-and-hold → open Oracle
                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                            haptic.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                NavigationStore.shared.selectedTab = 1
                            }
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
