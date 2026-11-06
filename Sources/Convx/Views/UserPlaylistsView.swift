import SwiftUI

public struct UserPlaylistsView: View {
    @ObservedObject private var playlistService = PlaylistService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateAlert = false
    @State private var newPlaylistTitle = ""

    public init() {}

    public var body: some View {
        ZStack {
            MeshGradientBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }

                    Spacer()

                    Text("Tus Playlists")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        showingCreateAlert = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.cyan)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Create Playlist Banner Button
                        Button(action: {
                            showingCreateAlert = true
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.cyan.opacity(0.18))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "plus")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.cyan)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Crear nueva playlist")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Organiza tu música a tu manera")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.55))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(14)
                            .liquidGlass(cornerRadius: 16, opacity: 0.6)
                            .padding(.horizontal, 18)
                        }
                        .buttonStyle(.plain)

                        if playlistService.playlists.isEmpty {
                            VStack(spacing: 14) {
                                Spacer().frame(height: 40)
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 54))
                                    .foregroundColor(.white.opacity(0.25))

                                Text("Sin playlists creadas")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                Text("Toca el botón '+' para crear tu primera lista de reproducción.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(playlistService.playlists) { playlist in
                                    NavigationLink(destination: UserPlaylistDetailView(playlistId: playlist.id)) {
                                        HStack(spacing: 14) {
                                            if let thumb = playlist.thumbnail {
                                                ArtworkImageView(urlString: thumb, size: 54, cornerRadius: 10)
                                            } else {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.white.opacity(0.08))
                                                        .frame(width: 54, height: 54)
                                                    Image(systemName: "music.note.list")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.white.opacity(0.35))
                                                }
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(playlist.title)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text(playlist.formattedSongCount)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(14)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 14)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Nueva Playlist", isPresented: $showingCreateAlert) {
            TextField("Nombre de la playlist", text: $newPlaylistTitle)
            Button("Crear") {
                if !newPlaylistTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    playlistService.createPlaylist(title: newPlaylistTitle)
                    newPlaylistTitle = ""
                }
            }
            Button("Cancelar", role: .cancel) {
                newPlaylistTitle = ""
            }
        } message: {
            Text("Ingresa un nombre para tu nueva lista de reproducción.")
        }
    }
}
