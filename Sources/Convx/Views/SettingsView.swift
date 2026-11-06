import SwiftUI

public struct SettingsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var sleepTimer = SleepTimerService.shared
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var dsp = AudiophileDSPService.shared
    @ObservedObject var dj = DJEngineService.shared
    @ObservedObject var neuro = BrainwaveModulatorService.shared
    @ObservedObject var singAlong = SingAlongService.shared
    @ObservedObject var livi = DJLiviService.shared
    @ObservedObject var liviVoice = DJLiviVoiceService.shared

    @AppStorage("audioQuality") private var audioQuality = "High (AAC 140 / 320k)"
    @AppStorage("crossfadeSeconds") private var crossfadeSeconds = 3.0
    @AppStorage("autoMixEnabled") private var autoMixEnabled = true
    @AppStorage("harmonicMixingEnabled") private var harmonicMixingEnabled = true
    // @AppStorage("notchIslandEnabled") private var notchIslandEnabled = true // Temporalmente en pausa

    @State private var showingCacheClearedAlert = false
    @State private var showingDSPSheet = false
    @State private var showingSingAlongSheet = false

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

                                // Notch Island (iPhone 16e & Notch Devices) - Comentado temporalmente
                                /*
                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Notch Island (iPhone 16e)")
                                            .foregroundColor(.white)
                                        Text("Transforma la notch en una isla interactiva con música en vivo")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Toggle("", isOn: $notchIslandEnabled)
                                        .tint(theme.activeAccentColor)
                                }
                                .padding(16)
                                */
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
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        // 3. SUITE DSP AUDIÓFILA & PROCESAMIENTO
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SUITE DSP AUDIÓFILA (10 BANDAS & ANALÓGICO)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                // Full 10-Band EQ Sheet Launcher
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    showingDSPSheet = true
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Calibración y Curvas de 10 Bandas")
                                                .foregroundColor(.white)
                                            Text("Preset activo: \(dsp.selectedPreset.rawValue)")
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.activeAccentColor)
                                        }
                                        Spacer()
                                        Image(systemName: "slider.vertical.3")
                                            .foregroundColor(theme.activeAccentColor)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(16)
                                }

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Preset Picker
                                HStack {
                                    Text("Preset Acústico")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { dsp.selectedPreset },
                                        set: { dsp.applyPreset($0) }
                                    )) {
                                        ForEach(AudiophileEQPreset.allCases) { preset in
                                            Text(preset.rawValue).tag(preset)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Analog Tube Warmth HD2
                                Toggle(isOn: $dsp.isTubeWarmthEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 13))
                                            Text("Calor Valvular Analógico (HD2)")
                                                .foregroundColor(.white)
                                        }
                                        Text("Distorsión armónica par de triodo 12AX7")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(.orange)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // Crossfeed Binaural
                                Toggle(isOn: $dsp.isCrossfeedEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "headphones")
                                                .foregroundColor(.cyan)
                                                .font(.system(size: 13))
                                            Text("Crossfeed Binaural (Bauer/Meier)")
                                                .foregroundColor(.white)
                                        }
                                        Text("Simulación acústica de monitores de estudio")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(.cyan)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                // EBU R128
                                Toggle(isOn: $dsp.isEbuR128Enabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 13))
                                            Text("Normalización EBU R128 / LUFS")
                                                .foregroundColor(.white)
                                        }
                                        Text("Sonoridad uniforme a -14 LUFS con True Peak Guard")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(.green)
                                .padding(16)
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        // 4. MOTOR SMART DJ & TRANSICIONES
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MOTOR SMART DJ & TRANSICIONES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                Toggle(isOn: $dj.isSmartDJEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Smart DJ Transitions")
                                            .foregroundColor(.white)
                                        Text("Mezcla activa según compás y tonalidad")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(theme.activeAccentColor)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Estilo de Transición")
                                            .foregroundColor(.white)
                                        Text(dj.selectedStyle.explanation)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Picker("", selection: $dj.selectedStyle) {
                                        ForEach(DJTransitionStyle.allCases) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Duración de Transición")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(String(format: "%.1fs", dj.transitionDuration))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Slider(value: $dj.transitionDuration, in: 3.0...8.0, step: 0.5)
                                        .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                Toggle(isOn: $dj.hapticDropsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Impacto Háptico en el Drop")
                                            .foregroundColor(.white)
                                        Text("Vibración sincronizada al entrar la nueva pista")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(theme.activeAccentColor)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                Toggle(isOn: $autoMixEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("AutoMix Vibe Radio")
                                            .foregroundColor(.white)
                                        Text("Reabastece la cola con recomendaciones armónicas")
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

                        // 5. ASISTENTE Y CURADORA DJ LIVI
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ASISTENTE Y CURADORA DJ LIVI")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                Toggle(isOn: $liviVoice.isVoiceEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Voz Neuronal de Livi")
                                            .foregroundColor(.white)
                                        Text("Locución de radio contextual con Apple Neural Engine")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .tint(theme.activeAccentColor)
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Voz Asignada")
                                            .foregroundColor(.white)
                                        Text(liviVoice.activeVoiceName)
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.activeAccentColor)
                                    }
                                    Spacer()
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        Task {
                                            await liviVoice.speak(text: "¡Qué onda! Soy DJ Livi, tu curadora musical en Convx. Todo listo para mezclar.")
                                        }
                                    }) {
                                        Text("Probar Voz")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(theme.activeAccentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Frecuencia de Locución")
                                            .foregroundColor(.white)
                                        Text("Intervención cada \(livi.talkFrequency) canciones")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    Picker("", selection: $livi.talkFrequency) {
                                        Text("Cada 2").tag(2)
                                        Text("Cada 3").tag(3)
                                        Text("Cada 4").tag(4)
                                        Text("Cada 5").tag(5)
                                    }
                                    .tint(theme.activeAccentColor)
                                }
                                .padding(16)

                                Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    livi.isSheetPresented = true
                                }) {
                                    HStack {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .foregroundColor(theme.activeAccentColor)
                                        Text("Abrir Chat con DJ Livi")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                    .padding(16)
                                }
                            }
                            .liquidGlass(cornerRadius: 18, opacity: 0.65)
                            .padding(.horizontal, 20)
                        }

                        // 6. MODULADOR NEUROACÚSTICO (BINAURAL BEATS)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MODULADOR NEUROACÚSTICO (BINAURAL BEATS)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Image(systemName: neuro.selectedBand.icon)
                                                .foregroundColor(.indigo)
                                                .font(.system(size: 13))
                                            Text("Frecuencia de Onda")
                                                .foregroundColor(.white)
                                        }
                                        Text(neuro.selectedBand.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.55))
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { neuro.selectedBand },
                                        set: { neuro.setBand($0) }
                                    )) {
                                        ForEach(BrainwaveBand.allCases) { band in
                                            Text(band.rawValue).tag(band)
                                        }
                                    }
                                    .tint(.indigo)
                                }
                                .padding(16)

                                if neuro.selectedBand != .off {
                                    Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Volumen del Subarmónico")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text("\(Int(neuro.volume * 100))%")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.indigo)
                                        }
                                        Slider(value: $neuro.volume, in: 0.1...1.0)
                                            .tint(.indigo)
                                    }
                                    .padding(16)

                                    Divider().background(Color.white.opacity(0.12)).padding(.leading, 16)

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Afinación Musical Automática")
                                                .foregroundColor(.white)
                                            Text("Portadora ajustada a \(Int(neuro.currentCarrierHz)) Hz según la tonalidad")
                                                .font(.system(size: 11))
                                                .foregroundColor(.indigo)
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.indigo)
                                    }
                                    .padding(16)
                                }
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
        .sheet(isPresented: $showingDSPSheet) {
            AudiophileDSPSheet()
        }
        .sheet(isPresented: $showingSingAlongSheet) {
            SingAlongSheet()
        }
        .alert("Caché Liberada", isPresented: $showingCacheClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Se ha liberado el espacio en disco de las canciones pre-cargadas.")
        }
    }
}
