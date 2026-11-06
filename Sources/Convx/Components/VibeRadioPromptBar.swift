import SwiftUI

public struct VibeRadioPromptBar: View {
    @ObservedObject var vibeService = VibeGeneratorService.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var promptText = ""
    @FocusState private var isFocused: Bool

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Title
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(theme.activeAccentColor)
                        .font(.system(size: 14, weight: .bold))
                    Text("PROMPT-TO-MUSIC / VIBE RADIO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                if vibeService.isGenerating {
                    ProgressView()
                        .tint(theme.activeAccentColor)
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 4)

            // Text Input Box
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(theme.activeAccentColor)
                    .font(.system(size: 16))

                TextField("Describe un ambiente, estado de ánimo o escena sonora...", text: $promptText)
                    .foregroundColor(.white)
                    .tint(theme.activeAccentColor)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        submitPrompt()
                    }

                if !promptText.isEmpty {
                    Button(action: { promptText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Button(action: {
                    submitPrompt()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(promptText.isEmpty ? .white.opacity(0.25) : theme.activeAccentColor)
                }
                .disabled(promptText.isEmpty || vibeService.isGenerating)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(cornerRadius: 16, opacity: 0.75)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [theme.activeAccentColor.opacity(0.6), Color.clear, Color.purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

            // Quick Inspiration Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vibeService.promptInspirations, id: \.prompt) { item in
                        Button(action: {
                            promptText = item.prompt
                            submitPrompt()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 10))
                                Text(item.tag)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }

            // Active Capsule Card if Present
            if let capsule = vibeService.currentCapsule {
                HStack(spacing: 12) {
                    // Procedural Capsule Art
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [capsule.primaryColor, capsule.secondaryColor, capsule.accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        )
                        .shadow(color: capsule.accentColor.opacity(0.4), radius: 6)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(capsule.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text("\(capsule.estimatedBPM) BPM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(capsule.accentColor)

                            ForEach(capsule.aestheticTags.prefix(2), id: \.self) { tag in
                                Text("• \(tag)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(capsule.accentColor)
                }
                .padding(12)
                .liquidGlass(cornerRadius: 16, opacity: 0.65)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func submitPrompt() {
        guard !promptText.isEmpty else { return }
        isFocused = false
        let text = promptText
        Task {
            _ = await vibeService.generateVibeRadio(prompt: text)
        }
    }
}
