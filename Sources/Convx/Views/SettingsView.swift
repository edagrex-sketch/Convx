import SwiftUI

public struct SettingsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var sleepTimer = SleepTimerService.shared
    @ObservedObject var player = AudioPlayerService.shared

    @AppStorage("audioQuality") private var audioQuality = "High (AAC 140 / 320k)"
    @AppStorage("crossfadeSeconds") private var crossfadeSeconds = 3.0
    @AppStorage("autoMixEnabled") private var autoMixEnabled = true
    @AppStorage("harmonicMixingEnabled") private var harmonicMixingEnabled = true

    @State private var showingCacheClearedAlert = false

    public init() {}

    private var cacheSizeString: String {
        guard let files = try? FileManager.default.contentsOfDirectory(at: AudioPlayerService.audioCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 MB" }
        var total: Int64 = 0
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        let mb = Double(total) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    private func clearAudioCache() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let files = try? FileManager.default.contentsOfDirectory(at: AudioPlayerService.audioCacheDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showingCacheClearedAlert = true
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.clear

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // 1. PERSONALIZACIÓN Y ESTILO
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PERSONALIZACIÓN Y ESTILO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                // Accent Color Swatches
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Color de Acento")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(theme.selectedAccent.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(theme.activeAccentColor)
                                    }

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(AccentColorOption.allCases) { opt in
                                                let isSelected = (theme.selectedAccent == opt)
                                                Button(action: {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.70)) {
                                                        theme.selectedAccent = opt
                                                    }
                                                }) {
                                                    ZStack {
                                                        if opt == .dynamicArtwork {
                                                            Circle()
                                                                .fill(
                                                                    AngularGradient(
                                                                        colors: [.red, .orange, .yellow, .green, .cyan, .purple, .red],
                                                                        center: .center
                                                                    )
                                                                )
                                                                .frame(width: 38, height: 38)
                                                        } else {
                                                            Circle()
                                                                .fill(opt.staticColor)
                                                                .frame(width: 38, height: 38)
                                                        }

                                                        if isSelected {
                                                            Circle()
                                                                .strokeBorder(Color.white, lineWidth: 2.8)
                                                                .frame(width: 44, height: 44)
                                                                .shadow(color: theme.activeAccentColor.opacity(0.6), radius: 6)

                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundColor(opt == .monochrome ? .black : .white)
                                                        }
                                                    }
                                                    .frame(width: 46, height: 46)
                                                    .scaleEffect(isSelected ? 1.08 : 1.0)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Liquid Glass Style
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Intensidad Liquid Glass")
                                            .foregroundColor(.white)
                                        Text("Ajusta la refracción y el desenfoque")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Picker("", selection: $theme.selectedGlassStyle) {
                                        ForEach(GlassStyle.allCases) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Player Mode Center Stage Style
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Estilo de Portada")
                                            .foregroundColor(.white)
                                        Text("Modo predeterminado en el reproductor")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Picker("", selection: $theme.selectedCoverStyle) {
                                        ForEach(PlayerCoverStyle.allCases) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        // 2. HERRAMIENTAS DE AUDIO Y REPRODUCCIÓN
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HERRAMIENTAS DE AUDIO Y REPRODUCCIÓN")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                // Sleep Timer
                                HStack {
                                    HStack(spacing: 10) {
                                        Image(systemName: "moon.stars.fill")
                                            .foregroundColor(sleepTimer.isActive ? theme.activeAccentColor : .white.opacity(0.6))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Temporizador de Sueño")
                                                .foregroundColor(.white)
                                            if sleepTimer.isActive {
                                                Text("Apagado en: \(sleepTimer.formattedRemainingTime)")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(theme.activeAccentColor)
                                            } else {
                                                Text("Apaga la música con fade out de 30s")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { sleepTimer.currentOption },
                                        set: { sleepTimer.setTimer(to: $0) }
                                    )) {
                                        ForEach(SleepTimerOption.allCases) { opt in
                                            Text(opt.rawValue).tag(opt)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Playback Speed
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Velocidad de Reproducción")
                                            .foregroundColor(.white)
                                        Text("Ajuste de tempo con tono musical fijo")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { sleepTimer.selectedSpeed },
                                        set: { sleepTimer.setSpeed($0) }
                                    )) {
                                        ForEach(PlaybackSpeed.allCases) { sp in
                                            Text(sp.label).tag(sp)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Equalizer Profile
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Perfil Acústico / EQ")
                                            .foregroundColor(.white)
                                        Text(sleepTimer.selectedPreset.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { sleepTimer.selectedPreset },
                                        set: { sleepTimer.setPreset($0) }
                                    )) {
                                        ForEach(EqualizerPreset.allCases) { preset in
                                            Text(preset.rawValue).tag(preset)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Shake to Shuffle
                                Toggle(isOn: $theme.shakeToShuffleEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Agitar para Aleatorio")
                                            .foregroundColor(.white)
                                        Text("Agita tu iPhone para alternar canciones")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .tint(theme.activeAccentColor)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // AutoMix
                                Toggle(isOn: $autoMixEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("AutoMix & DJ Radio")
                                            .foregroundColor(.white)
                                        Text("Reabastece la cola con canciones similares")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .tint(theme.activeAccentColor)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Crossfade
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Crossfade")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(crossfadeSeconds))s")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Slider(value: $crossfadeSeconds, in: 0...12, step: 1)
                                        .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                Toggle(isOn: $harmonicMixingEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Mezcla Armónica Camelot")
                                            .foregroundColor(.white)
                                        Text("Transiciones fluidas ordenando tonalidades compatibles")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(theme.activeAccentColor)
                                .padding(16)
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        // 3. CALIDAD Y ALMACENAMIENTO
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CALIDAD Y ALMACENAMIENTO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                HStack {
                                    Text("Calidad de Transmisión")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("", selection: $audioQuality) {
                                        Text("Alta (AAC 140 / 320k)").tag("High (AAC 140 / 320k)")
                                        Text("Estándar (AAC 139)").tag("Standard (AAC 139)")
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Caché de Audio")
                                            .foregroundColor(.white)
                                        Text(cacheSizeString)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Button(action: clearAudioCache) {
                                        Text("Liberar Espacio")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(16)
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        // 4. ACERCA DE
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ACERCA DE CONVX")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                HStack {
                                    Text("Versión de Convx")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("v2.0.4 Native Pro")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    Text("Rendimiento")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("120Hz ProMotion Native")
                                        .foregroundColor(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    Text("Diseño")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Liquid Glass / Cupertino")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    Text("Licencia")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("GPL-3.0 Open Source")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(16)
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 120)
                    }
                }
            }
        }
        .alert("Caché Liberada", isPresented: $showingCacheClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Se ha liberado el espacio en disco de las canciones pre-cargadas.")
        }
    }
}
