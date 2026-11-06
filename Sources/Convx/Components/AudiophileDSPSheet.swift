import SwiftUI

public struct AudiophileDSPSheet: View {
    @ObservedObject var dsp = AudiophileDSPService.shared
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Preset Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PRESET AUDIÓFILO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(AudiophileEQPreset.allCases) { preset in
                                        Button(action: {
                                            dsp.applyPreset(preset)
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Image(systemName: preset.icon)
                                                        .font(.system(size: 14))
                                                    Text(preset.rawValue)
                                                        .font(.system(size: 13, weight: .semibold))
                                                }
                                                Text(preset.subtitle)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.white.opacity(0.6))
                                                    .lineLimit(2)
                                                    .frame(maxWidth: 160, alignment: .leading)
                                            }
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(
                                                dsp.selectedPreset == preset
                                                    ? theme.activeAccentColor.opacity(0.35)
                                                    : Color.white.opacity(0.06)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(dsp.selectedPreset == preset ? theme.activeAccentColor : Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // 10-Band Graphic EQ Sliders View
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ECUALIZADOR DE 10 BANDAS (ISO 266)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))
                                Spacer()
                                Button("Reiniciar") {
                                    dsp.applyPreset(.flat)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.activeAccentColor)
                            }

                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(0..<AudiophileDSPService.isoFrequencies.count, id: \.self) { idx in
                                    let freq = AudiophileDSPService.isoFrequencies[idx]
                                    let freqLabel: String = (freq >= 1000) ? "\(Int(freq / 1000))k" : "\(Int(freq))"
                                    let gain = dsp.customBandGains[idx]

                                    VStack(spacing: 6) {
                                        Text(String(format: "%+.1f", gain))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(gain != 0 ? theme.activeAccentColor : .white.opacity(0.4))

                                        // Slider Track Simulation
                                        ZStack(alignment: .bottom) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 8, height: 110)

                                            // Center line at 0dB
                                            Rectangle()
                                                .fill(Color.white.opacity(0.25))
                                                .frame(width: 14, height: 1)
                                                .offset(y: -55)

                                            // Fill representation
                                            let normalized = (CGFloat(gain) + 12.0) / 24.0
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(theme.activeAccentColor)
                                                .frame(width: 8, height: max(4, normalized * 110))
                                        }
                                        .frame(height: 110)

                                        Text(freqLabel)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.65))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(16)
                        .liquidGlass(cornerRadius: 18, opacity: 0.6)
                        .padding(.horizontal, 20)

                        // Analog Tube Warmth & HD2 Saturation
                        VStack(spacing: 12) {
                            Toggle(isOn: $dsp.isTubeWarmthEnabled) {
                                HStack(spacing: 10) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Calor Valvular Analógico (HD2)")
                                            .foregroundColor(.white)
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Inyecta armónicos pares de segundo orden tipo triodo 12AX7")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                            }
                            .tint(.orange)

                            if dsp.isTubeWarmthEnabled {
                                HStack {
                                    Text("Saturación / Drive")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("\(Int(dsp.tubeDrive * 100))%")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                                Slider(value: $dsp.tubeDrive, in: 0.0...1.0)
                                    .tint(.orange)
                            }
                        }
                        .padding(16)
                        .liquidGlass(cornerRadius: 18, opacity: 0.6)
                        .padding(.horizontal, 20)

                        // 3D Binaural Crossfeed
                        VStack(spacing: 12) {
                            Toggle(isOn: $dsp.isCrossfeedEnabled) {
                                HStack(spacing: 10) {
                                    Image(systemName: "headphones")
                                        .foregroundColor(.cyan)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Crossfeed Binaural (Bauer/Meier)")
                                            .foregroundColor(.white)
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Proyecta el sonido como monitores de estudio eliminando fatiga")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                            }
                            .tint(.cyan)

                            if dsp.isCrossfeedEnabled {
                                HStack {
                                    Text("Intensidad Acústica")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("\(Int(dsp.crossfeedLevel * 100))%")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.cyan)
                                }
                                Slider(value: $dsp.crossfeedLevel, in: 0.0...1.0)
                                    .tint(.cyan)
                            }
                        }
                        .padding(16)
                        .liquidGlass(cornerRadius: 18, opacity: 0.6)
                        .padding(.horizontal, 20)

                        // EBU R128 Normalizer
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $dsp.isEbuR128Enabled) {
                                HStack(spacing: 10) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Normalización EBU R128 / LUFS")
                                            .foregroundColor(.white)
                                            .font(.system(size: 15, weight: .medium))
                                        Text("Nivel constante a -14 LUFS con True Peak Guard")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                            }
                            .tint(.green)
                        }
                        .padding(16)
                        .liquidGlass(cornerRadius: 18, opacity: 0.6)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 30)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Suite DSP Audiófila")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .foregroundColor(theme.activeAccentColor)
                }
            }
        }
    }
}
