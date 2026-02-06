//
//  PlaylistListView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit

struct PlaylistListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playerManager: ChorusPlayerManager
    @EnvironmentObject private var storeManager: StoreManager
    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]
    
    @State private var showingCreateSheet = false
    @State private var showingSettings = false
    @State private var showingImportSheet = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var newPlaylistName = ""
    @State private var backgroundArtworkURL: URL?
    @State private var showingPaywall = false
    @State private var showingImportLimitAlert = false
    @State private var skippedTrackCount = 0
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                
                // オーバーレイ
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                
                mainContent
            }
            .task(id: playlists.count) {
                await updateBackgroundArtwork()
            }
            .task(id: customBackgroundArtworkURLString) {
                await updateBackgroundArtwork()
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
                    Text("マイリスト")
                        .font(.headline)
                        .bold()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { handleAddPlaylist() }) {
                            Label("新規ハイライトリスト", systemImage: "plus")
                        }
                        Button(action: { handleImportAppleMusic() }) {
                            Label(String(localized: "import_apple_music"), systemImage: "music.note")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
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
            .alert(String(localized: "import_error"), isPresented: $showingImportError) {
                Button(String(localized: "ok"), role: .cancel) {}
            } message: {
                Text(importError ?? String(localized: "unknown_error"))
            }
            .alert(String(localized: "import_limit_title"), isPresented: $showingImportLimitAlert) {
                Button(String(localized: "upgrade_to_premium")) {
                    showingPaywall = true
                }
                Button(String(localized: "ok"), role: .cancel) {}
            } message: {
                Text(String(localized: "import_limit_message_\(skippedTrackCount)"))
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
    
    /// プレイリスト追加制限をチェック
    private var canAddPlaylist: Bool {
        storeManager.isPremium || playlists.count < FreeTierLimits.maxPlaylists
    }
    
    /// プレイリスト追加ボタンの処理
    private func handleAddPlaylist() {
        if canAddPlaylist {
            showingCreateSheet = true
        } else {
            showingPaywall = true
        }
    }
    
    /// Apple Musicインポートの処理
    private func handleImportAppleMusic() {
        if canAddPlaylist {
            showingImportSheet = true
        } else {
            showingPaywall = true
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
    
    private func updateBackgroundArtwork() async {
        // 1. カスタム背景設定がある場合はそれを優先
        if !customBackgroundArtworkURLString.isEmpty, let url = URL(string: customBackgroundArtworkURLString) {
            backgroundArtworkURL = url
            return
        }
        
        // 2. 設定がない場合は、既存のランダムロジック
        // 各プレイリストの1番目のトラックを収集
        let firstTracks = playlists.compactMap { $0.sortedTracks.first }
        guard !firstTracks.isEmpty else {
            backgroundArtworkURL = nil
            return
        }
        
        // ランダムにトラックを選択
        let randomTrack = firstTracks.randomElement()!
        
        // キャッシュがあればそれを使用
        if let cachedURL = randomTrack.artworkURL {
            backgroundArtworkURL = cachedURL
            return
        }
        
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(randomTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                let url = artwork.url(width: 400, height: 400)
                backgroundArtworkURL = url
                
                // キャッシュに保存
                randomTrack.artworkURL = url
            }
        } catch {
            print("Background artwork load error: \(error)")
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundView: some View {
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
                .id(url) // URLが変わったらビューを再作成
                .transition(.opacity)
            } else {
                Color(.systemBackground)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: backgroundArtworkURL)
    }
    
    private var mainContent: some View {
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
                    
                    // ハイライトリストを追加ボタン
                    Button(action: { handleAddPlaylist() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.primary)
                            Text("ハイライトリストを追加")
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
        
        // キャッシュがあればそれを使用
        if let cachedURL = firstTrack.artworkURL {
            artworkURL = cachedURL
            return
        }
        
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                let url = artwork.url(width: 100, height: 100)
                artworkURL = url
                
                // キャッシュに保存
                firstTrack.artworkURL = url
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
                TextField("リスト名", text: $playlistName)
                    .onChange(of: playlistName) { _, newValue in
                        // 50文字制限
                        if newValue.count > PlaylistValidator.maxNameLength {
                            playlistName = String(newValue.prefix(PlaylistValidator.maxNameLength))
                        }
                    }
            }
            .navigationTitle("新規ハイライトリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
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
