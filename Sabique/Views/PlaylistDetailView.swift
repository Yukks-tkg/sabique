//
//  PlaylistDetailView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var playlist: Playlist
    
    @State private var showingAddSong = false
    @State private var selectedTrack: TrackInPlaylist?
    @State private var showingChorusEdit = false
    @State private var backgroundArtworkURL: URL?
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    
    // 1曲目のID（並べ替え検知用）
    private var firstTrackId: String? {
        playlist.sortedTracks.first?.appleMusicSongId
    }
    
    @StateObject private var playerManager = ChorusPlayerManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                    .id(url) // URLが変わったらビューを再作成
                    .transition(.opacity)
                } else {
                    Color(.systemBackground)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: backgroundArtworkURL)
            
            // オーバーレイ
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            
            // コンテンツ
            List {
                // 曲リスト
                Section {
                    if playlist.sortedTracks.isEmpty {
                        Text(String(localized: "no_songs"))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(playlist.sortedTracks) { track in
                            let isCurrentlyPlaying = playerManager.isPlaying && playerManager.currentTrack?.id == track.id
                            TrackRow(track: track, isPlaying: isCurrentlyPlaying)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isCurrentlyPlaying ? Color.white.opacity(0.2) : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTrack = track
                                    showingChorusEdit = true
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteTracks)
                        .onMove(perform: moveTracks)
                    }
                    
                    // トラックを追加ボタン
                    Button(action: { showingAddSong = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.primary)
                            Text(String(localized: "add_track"))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text(playlist.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 10)
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80) // 下部にスペースを確保
            }
            .task(id: firstTrackId) {
                await loadFirstTrackArtwork()
            }
            
            // 再生コントロール（下部に固定）
            if !playlist.sortedTracks.isEmpty {
                VStack(spacing: 0) {
                    HStack(spacing: 20) {
                        // 前のトラックボタン
                        Button(action: { playerManager.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(14)
                        }
                        .disabled(!playerManager.isPlaying)
                        .opacity(playerManager.isPlaying ? 1.0 : 0.4)
                        
                        // 連続再生/停止ボタン
                        Button(action: startPlayback) {
                            HStack(spacing: 12) {
                                Image(systemName: playerManager.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.title3)
                                Text(playerManager.isPlaying ? String(localized: "stop") : String(localized: "play"))
                                    .font(.headline)
                                    .bold()
                            }
                            .foregroundColor(.white)
                            .frame(width: 160)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        
                        // 次のトラックボタン
                        Button(action: { playerManager.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(14)
                        }
                        .disabled(!playerManager.isPlaying)
                        .opacity(playerManager.isPlaying ? 1.0 : 0.4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .animation(nil, value: playerManager.isPlaying)
            }
        }
        .navigationTitle(String(localized: "highlight_list"))
        .preferredColorScheme(.dark)
        .toolbar {
            // エクスポートボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: exportPlaylist) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || playlist.sortedTracks.isEmpty)
            }
            
            // 曲追加ボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSong = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSong) {
            SongSearchView(playlist: playlist)
        }
        .sheet(item: $selectedTrack) { track in
            ChorusEditView(track: track)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func startPlayback() {
        if playerManager.isPlaying {
            playerManager.stop()
        } else {
            playerManager.play(tracks: playlist.sortedTracks)
        }
    }
    
    private func deleteTracks(at offsets: IndexSet) {
        let sortedTracks = playlist.sortedTracks
        for index in offsets {
            modelContext.delete(sortedTracks[index])
        }
    }
    
    private func moveTracks(from source: IndexSet, to destination: Int) {
        var tracks = playlist.sortedTracks
        tracks.move(fromOffsets: source, toOffset: destination)
        
        // orderIndexを更新
        for (index, track) in tracks.enumerated() {
            track.orderIndex = index
        }
    }
    
    private func loadFirstTrackArtwork() async {
        guard let firstTrack = playlist.sortedTracks.first else {
            backgroundArtworkURL = nil
            return
        }
        
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                backgroundArtworkURL = artwork.url(width: 400, height: 400)
            }
        } catch {
            print("Background artwork load error: \(error)")
        }
    }
    
    private func exportPlaylist() {
        isExporting = true
        Task {
            do {
                let fileURL = try await PlaylistExporter.exportToFile(playlist: playlist)
                await MainActor.run {
                    exportedFileURL = fileURL
                    showingShareSheet = true
                    isExporting = false
                }
            } catch {
                print("Export error: \(error)")
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - TrackRow
struct TrackRow: View {
    let track: TrackInPlaylist
    var isPlaying: Bool = false
    @State private var artworkURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            // アートワーク
            if let url = artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if track.hasChorusSettings {
                Text("\(track.chorusStartFormatted) - \(track.chorusEndFormatted)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .task {
            await loadArtwork()
        }
    }
    
    private func loadArtwork() async {
        var song: Song?
        
        // まずIDで検索（エラーをキャッチして続行）
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(track.appleMusicSongId)
            )
            let response = try await request.response()
            song = response.items.first
        } catch {
            print("⚠️ ID search failed for artwork: \(error)")
        }
        
        // IDで見つからない場合はタイトルとアーティストで検索
        if song == nil {
            do {
                var searchRequest = MusicCatalogSearchRequest(term: "\(track.title) \(track.artist)", types: [Song.self])
                searchRequest.limit = 5
                let searchResponse = try await searchRequest.response()
                song = searchResponse.songs.first { $0.title == track.title && $0.artistName == track.artist }
                    ?? searchResponse.songs.first
            } catch {
                print("❌ Text search also failed for artwork: \(error)")
            }
        }
        
        if let foundSong = song, let artwork = foundSong.artwork {
            artworkURL = artwork.url(width: 100, height: 100)
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(playlist: Playlist(name: "テストプレイリスト"))
    }
    .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}
