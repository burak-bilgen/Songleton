import SwiftUI
import Combine

struct VolumeSliderPanelView: View {
    @ObservedObject var model = NowPlayingModel.shared

    @State private var localVolume: Double = 50.0
    @State private var isDragging: Bool = false
    @State private var lastSetTime: Date = .distantPast
    @State private var volumeSubject = PassthroughSubject<Int, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isMutePressed = false
    @State private var appearScale: CGFloat = 0.85
    @State private var appearOpacity: Double = 0.0

    private var modelVolume: Double {
        if case .loaded(let info, _) = model.state {
            return Double(info.volume)
        }
        return 50.0
    }

    private var activeVolume: Double {
        if isDragging || Date().timeIntervalSince(lastSetTime) < 2.0 {
            return localVolume
        }
        return modelVolume
    }

    var body: some View {
        ZStack {
            // Pure Jet Black Clean Background with Subtle Rim
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.7), radius: 14, x: 0, y: 6)

            HStack(spacing: 14) {
                // Mute / Speaker Icon Button
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { isMutePressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { isMutePressed = false }
                    }
                    toggleMute()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                            .frame(width: 32, height: 32)

                        Image(systemName: speakerIconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(activeVolume == 0 ? Color.red : Color.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(isMutePressed ? 0.82 : 1.0)

                // Larger Interactive Slider
                Slider(
                    value: Binding(
                        get: { activeVolume },
                        set: { newVol in
                            localVolume = newVol
                            isDragging = true
                            lastSetTime = Date()
                            volumeSubject.send(Int(newVol))
                        }
                    ),
                    in: 0...100,
                    onEditingChanged: { editing in
                        isDragging = editing
                        if !editing {
                            lastSetTime = Date()
                            model.setVolume(Int(localVolume))
                        }
                    }
                )
                .tint(Color.accentColor)

                // Percentage Badge
                Text("\(Int(activeVolume))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.horizontal, 14)
        }
        .frame(width: 290, height: 54)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            localVolume = modelVolume

            withAnimation(.spring(response: 0.36, dampingFraction: 0.54)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }

            volumeSubject
                .debounce(for: .milliseconds(60), scheduler: DispatchQueue.main)
                .removeDuplicates()
                .sink { newVol in
                    NowPlayingModel.shared.setVolume(newVol)
                }
                .store(in: &cancellables)
        }
        .onChange(of: modelVolume) { _, newVol in
            if !isDragging && Date().timeIntervalSince(lastSetTime) >= 2.0 {
                localVolume = newVol
            }
        }
    }

    private var speakerIconName: String {
        let vol = activeVolume
        if vol == 0 {
            return "speaker.slash.fill"
        } else if vol < 33 {
            return "speaker.wave.1.fill"
        } else if vol < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func toggleMute() {
        lastSetTime = Date()
        let current = activeVolume
        if current > 0 {
            localVolume = 0
            model.setVolume(0)
        } else {
            localVolume = 50
            model.setVolume(50)
        }
    }
}
