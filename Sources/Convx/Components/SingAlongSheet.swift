import SwiftUI

public struct SingAlongSheet: View {
    @ObservedObject var singAlong = SingAlongService.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Ambient background glow
            RadialGradient(
                colors: [Color.pink.opacity(0.22), Color.black],
                center: .top,
                startRadius: 20,
                endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Grabber
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                // Header Title & Active Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.pink)
                            Text("Sing-Along & Karaoke")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Atenuación vocal y transposición en tiempo real")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $singAlong.isSingAlongEnabled)
                        .tint(.pink)
                        .labelsHidden()
                        .onChange(of: singAlong.isSingAlongEnabled) { _, enabled in
                            if enabled {
                                singAlong.applyMode(.karaoke)
                            } else {
                                singAlong.vocalVolume = 1.0
                                singAlong.pitchSemitones = 0
                            }
                        }
                }
                .padding(.horizontal, 24)

                Divider().background(Color.white.opacity(0.12))

                // Vocal Preset Buttons
                VStack(alignment: .leading, spacing: 10) {
                    Text("MODO VOCAL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))

                    HStack(spacing: 8) {
                        ForEach(SingAlongVocalMode.allCases) { mode in
                            Button(action: {
                                singAlong.applyMode(mode)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 18))
                                    Text(mode.rawValue)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                }
                                .foregroundColor(singAlong.selectedMode == mode ? .white : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    singAlong.selectedMode == mode ? Color.pink.opacity(0.35) : Color.white.opacity(0.06)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(singAlong.selectedMode == mode ? Color.pink : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Vocal Attenuation Slider (0% to 100%)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Nivel de Voz Principal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(singAlong.vocalVolume * 100))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.pink)
                    }

                    Slider(value: $singAlong.vocalVolume, in: 0.0...1.5, step: 0.05)
                        .tint(.pink)
                }
                .padding(.horizontal, 24)
                .liquidGlass(cornerRadius: 16, opacity: 0.5)
                .padding(.horizontal, 16)

                // Pitch Transposition Controls (+/- Semitones)
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Afinación / Transporte Tonal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Ajusta el tono de la música a tu rango vocal")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Text(singAlong.formattedPitch)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.pink)
                    }

                    HStack(spacing: 16) {
                        Button(action: { singAlong.decrementPitch() }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Button(action: { singAlong.resetPitch() }) {
                            Text("Original")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Button(action: { singAlong.incrementPitch() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16, opacity: 0.5)
                .padding(.horizontal, 16)

                Spacer()

                // Close Button
                Button("Listo") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.pink)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .fraction(0.68)])
        .presentationDragIndicator(.visible)
    }
}
