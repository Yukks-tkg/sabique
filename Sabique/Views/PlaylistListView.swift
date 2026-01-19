//
//  PlaylistListView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit
import UniformTypeIdentifiers

struct PlaylistListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playerManager: ChorusPlayerManager
    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]
    
    @State private var showingCreateSheet = false
    @State private var showingSettings = false
    @State private var showingImportSheet = false
    @State private var showingFileImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var newPlaylistName = ""
    @State private var backgroundArtworkURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // ぼかし背景
                GeometryReader { geometry in
                    if let url = backgroundArtworkURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .blur(radius: 30)
                                .opacity(0.6)
                        } placeholder: {
                            Color.black
                        }
                    } else {
                        Color(.systemBackground)
                    }
                }
                .ignoresSafeArea()
                
                // オーバーレイ
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                
                // コンテンツ
                Group {
                    if playlists.isEmpty {
                        ContentUnavailableView(
                            String(localized: "no_playlists"),
                            systemImage: "music.note.list",
                            description: Text(String(localized: "no_playlists_description"))
                        )
                    } else {
                        List {
                            ForEach(playlists) { playlist in
                                let isPlayingFromThisPlaylist = playerManager.isPlaying && playlist.sortedTracks.contains(where: { $0.id == playerManager.currentTrack?.id })
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    PlaylistRow(playlist: playlist)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isPlayingFromThisPlaylist ? Color.white.opacity(0.2) : Color.clear)
                                        )
                                }
                                .listRowSeparator(.visible, edges: .bottom)
                                .listRowBackground(Color.clear)
                            }
                            .onDelete(perform: deletePlaylists)
                            .onMove(perform: movePlaylists)
                            
                            // プレイリストを追加ボタン
                            Button(action: { showingCreateSheet = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                    Text(String(localized: "add_playlist"))
                                        .foregroundColor(.primary)
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .task(id: playlists.count) {
                await loadRandomArtwork()
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(String(localized: "playlists"))
                        .font(.headline)
                        .bold()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateSheet = true }) {
                            Label(String(localized: "new_playlist"), systemImage: "plus")
                        }
                        Button(action: { showingImportSheet = true }) {
                            Label(String(localized: "import_apple_music"), systemImage: "music.note")
                        }
                        Button(action: { showingFileImporter = true }) {
                            Label(String(localized: "import_file"), systemImage: "doc.badge.arrow.up")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreatePlaylistSheet(
                    playlistName: $newPlaylistName,
                    onCreate: createPlaylist,
                    onCancel: { showingCreateSheet = false }
                )
            }
            .sheet(isPresented: $showingImportSheet) {
                AppleMusicPlaylistImportView { importedPlaylist in
                    // インポート成功時の処理（必要に応じて）
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [UTType.json, UTType(filenameExtension: "sabique") ?? UTType.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert(String(localized: "import_error"), isPresented: $showingImportError) {
                Button(String(localized: "ok"), role: .cancel) {}
            } message: {
                Text(importError ?? String(localized: "unknown_error"))
            }
        }
    }
    
    private func createPlaylist() {
        guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 新しいプレイリストは一番上に追加（orderIndex = 0）
        // 既存のプレイリストの orderIndex をインクリメント
        for playlist in playlists {
            playlist.orderIndex += 1
        }
        
        let playlist = Playlist(name: newPlaylistName.trimmingCharacters(in: .whitespaces), orderIndex: 0)
        modelContext.insert(playlist)
        
        newPlaylistName = ""
        showingCreateSheet = false
    }
    
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(playlists[index])
        }
    }
    
    private func movePlaylists(from source: IndexSet, to destination: Int) {
        var reorderedPlaylists = playlists
        reorderedPlaylists.move(fromOffsets: source, toOffset: destination)
        
        // orderIndexを更新
        for (index, playlist) in reorderedPlaylists.enumerated() {
            playlist.orderIndex = index
        }
    }
    
    private func loadRandomArtwork() async {
        // 各プレイリストの1番目のトラックを収集
        let firstTracks = playlists.compactMap { $0.sortedTracks.first }
        guard !firstTracks.isEmpty else {
            backgroundArtworkURL = nil
            return
        }
        
        // ランダムにトラックを選択
        let randomTrack = firstTracks.randomElement()!
        
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(randomTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                backgroundArtworkURL = artwork.url(width: 400, height: 400)
            }
        } catch {
            print("Background artwork load error: \(error)")
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            
            Task {
                do {
                    // 既存のプレイリストのorderIndexを更新
                    for playlist in playlists {
                        playlist.orderIndex += 1
                    }
                    
                    let _ = try await PlaylistImporter.importFromFile(url: url, modelContext: modelContext)
                    await MainActor.run {
                        isImporting = false
                    }
                } catch {
                    await MainActor.run {
                        importError = error.localizedDescription
                        showingImportError = true
                        isImporting = false
                    }
                }
            }
            
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

// MARK: - PlaylistRow
struct PlaylistRow: View {
    let playlist: Playlist
    @State private var artworkURL: URL?
    
    var body: some View {
        HStack(spacing: 16) {
            // プレイリストのアートワーク（最初の曲から取得）
            if let url = artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    playlistPlaceholder
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                playlistPlaceholder
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(playlist.trackCount)" + String(localized: "track_count_format"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .task(id: playlist.trackCount) {
            await loadFirstTrackArtwork()
        }
    }
    
    private var playlistPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
            
            Image(systemName: "music.note.list")
                .foregroundColor(.blue)
                .font(.title3)
        }
    }
    
    private func loadFirstTrackArtwork() async {
        guard let firstTrack = playlist.sortedTracks.first else { return }
        
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                artworkURL = artwork.url(width: 100, height: 100)
            }
        } catch {
            print("Artwork load error: \(error)")
        }
    }
}

// MARK: - CreatePlaylistSheet
struct CreatePlaylistSheet: View {
    @Binding var playlistName: String
    let onCreate: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "playlist_name"), text: $playlistName)
            }
            .navigationTitle(String(localized: "new_playlist"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "create"), action: onCreate)
                        .disabled(playlistName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    PlaylistListView()
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}
