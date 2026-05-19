import SwiftUI

struct RitualStep: Identifiable {
    let id = UUID()
    let chakraName: ChakraName
    var durationMinutes: Int

    var chakra: ChakraProtocol {
        ChakraData.all[chakraName]!
    }
}

struct RitualSetupView: View {
    let onBegin: ([RitualStep]) -> Void

    @State private var queue: [RitualStep] = []

    private let theme = ThemeData.void
    private let durationOptions = [3, 5, 10, 15]

    private var totalMinutes: Int {
        queue.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Ritual")
                        .font(.system(size: 32, weight: .ultraLight, design: .serif))
                        .italic()
                        .foregroundColor(theme.text)
                    Text("weave a sequence")
                        .font(.system(size: 14))
                        .foregroundColor(theme.muted)
                }
                .padding(.top, 30)
                .padding(.bottom, 16)

                // Queue
                if queue.isEmpty {
                    Text("Tap chakras below to add steps")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundColor(theme.subtle)
                        .padding(.vertical, 40)
                } else {
                    List {
                        ForEach(queue.indices, id: \.self) { idx in
                            QueueRow(
                                step: queue[idx],
                                stepNumber: idx + 1,
                                onCycleDuration: {
                                    let current = queue[idx].durationMinutes
                                    let next: Int
                                    if let pos = durationOptions.firstIndex(of: current) {
                                        next = durationOptions[(pos + 1) % durationOptions.count]
                                    } else {
                                        next = 5
                                    }
                                    queue[idx].durationMinutes = next
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(theme.muted.opacity(0.15))
                        }
                        .onMove { from, to in queue.move(fromOffsets: from, toOffset: to) }
                        .onDelete { offsets in queue.remove(atOffsets: offsets) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: 240)
                    .environment(\.editMode, .constant(.active))

                    Text("\(totalMinutes) min total · \(queue.count) step\(queue.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(theme.subtle)
                        .padding(.vertical, 8)
                }

                Rectangle()
                    .fill(theme.muted.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                // Chakra picker
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(orderedChakras, id: \.name) { chakra in
                            ChakraAddTile(chakra: chakra)
                                .onTapGesture {
                                    queue.append(RitualStep(chakraName: chakra.name, durationMinutes: 5))
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 200)

                // Begin button
                Button(action: { onBegin(queue) }) {
                    Text("Begin Ritual")
                        .font(.system(size: 17, weight: .light, design: .serif))
                        .italic()
                        .foregroundColor(theme.bg)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(queue.count >= 2 ? theme.text : theme.muted.opacity(0.3)))
                }
                .disabled(queue.count < 2)
                .padding(.vertical, 16)
            }
        }
    }
}

private struct QueueRow: View {
    let step: RitualStep
    let stepNumber: Int
    let onCycleDuration: () -> Void
    private let theme = ThemeData.void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(stepNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.subtle)
                .frame(width: 18)
            Circle()
                .fill(step.chakra.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.chakra.name.rawValue)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundColor(theme.text)
                Text(step.chakra.center)
                    .font(.system(size: 9))
                    .foregroundColor(theme.subtle)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            Spacer()
            Button(action: onCycleDuration) {
                Text("\(step.durationMinutes) min")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct ChakraAddTile: View {
    let chakra: ChakraProtocol
    private let theme = ThemeData.void

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(chakra.color)
                .frame(width: 24, height: 24)
            Text(chakra.name.rawValue)
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundColor(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.muted.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
