//
//  SongSearchView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit

struct SongSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let playlist: Playlist
    
    @State private var searchKeyword = ""
    @State private var songs: MusicItemCollection<Song> = []
    @State private var recentlyPlayedSongs: [Song] = []
    @State private var isSearching = false
    @State private var isLoadingRecent = false
    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @State private var addedTrack: TrackInPlaylist?
    @State private var showingChorusEdit = false
    @State private var searchTask: Task<Void, Never>?
    
    /// 表示する曲リスト（検索中は検索結果、それ以外は最近再生した曲）
    private var displayedSongs: [Song] {
        if !searchKeyword.isEmpty {
            return Array(songs)
        } else {
            return recentlyPlayedSongs
        }
    }
    
    private var sectionTitle: String {
        if !searchKeyword.isEmpty {
            return String(localized: "search_results")
        } else {
            return String(localized: "recently_played")
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if authorizationStatus != .authorized {
                    ContentUnavailableView(
                        String(localized: "apple_music_access_required"),
                        systemImage: "music.note",
                        description: Text(String(localized: "apple_music_access_description"))
                    )
                } else {
                    VStack {
                        // 検索バー
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField(String(localized: "search_placeholder"), text: $searchKeyword)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                            if !searchKeyword.isEmpty {
                                Button(action: { searchKeyword = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // コンテンツ
                        if isSearching || isLoadingRecent {
                            ProgressView(isSearching ? String(localized: "searching") : String(localized: "loading"))
                                .frame(maxHeight: .infinity)
                        } else if displayedSongs.isEmpty {
                            if !searchKeyword.isEmpty {
                                ContentUnavailableView.search(text: searchKeyword)
                            } else {
                                ContentUnavailableView(
                                    String(localized: "no_recently_played"),
                                    systemImage: "clock",
                                    description: Text(String(localized: "no_recently_played_description"))
                                )
                            }
                        } else {
                            List {
                                Section(header: Text(sectionTitle).foregroundColor(.secondary)) {
                                    ForEach(displayedSongs, id: \.id) { song in
                                        SongRow(
                                            song: song,
                                            onAdd: { addSongDirectly(song) },
                                            onEdit: { addSongWithEdit(song) }
                                        )
                                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "add_song"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) { dismiss() }
                }
            }
            .onAppear {
                Task {
                    authorizationStatus = await MusicAuthorization.request()
                    if authorizationStatus == .authorized {
                        await loadRecentlyPlayedSongs()
                    }
                }
            }
            .sheet(item: $addedTrack, onDismiss: { dismiss() }) { track in
                ChorusEditView(track: track)
            }
            .onChange(of: searchKeyword) { oldValue, newValue in
                // 既存の検索タスクをキャンセル
                searchTask?.cancel()
                
                // 空の場合は検索結果をクリア
                if newValue.isEmpty {
                    songs = []
                    return
                }
                
                // デバウンス（0.3秒待ってから検索）
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await searchMusic()
                }
            }
        }
    }
    
    /// 最近再生した曲を取得
    private func loadRecentlyPlayedSongs() async {
        isLoadingRecent = true
        defer { isLoadingRecent = false }
        
        do {
            let request = MusicRecentlyPlayedRequest<Song>()
            let response = try await request.response()
            recentlyPlayedSongs = Array(response.items.prefix(20))
        } catch {
            print("Recently played songs load error: \(error)")
        }
    }
    
    private func searchMusic() async {
        guard !searchKeyword.isEmpty else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            var request = MusicCatalogSearchRequest(term: searchKeyword, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            self.songs = response.songs
        } catch {
            print("検索エラー: \(error)")
        }
    }
    
    /// 曲を直接追加（ChorusEditViewなし）
    private func addSongDirectly(_ song: Song) {
        Task {
            let catalogSongId = await getCatalogSongId(song: song)
            
            await MainActor.run {
                let track = TrackInPlaylist(
                    appleMusicSongId: catalogSongId,
                    title: song.title,
                    artist: song.artistName,
                    orderIndex: playlist.tracks.count
                )
                track.playlist = playlist
                modelContext.insert(track)
                
                // ハイライトリストに戻る
                dismiss()
            }
        }
    }
    
    /// 曲を追加してChorusEditViewを表示
    private func addSongWithEdit(_ song: Song) {
        Task {
            let catalogSongId = await getCatalogSongId(song: song)
            
            await MainActor.run {
                let track = TrackInPlaylist(
                    appleMusicSongId: catalogSongId,
                    title: song.title,
                    artist: song.artistName,
                    orderIndex: playlist.tracks.count
                )
                track.playlist = playlist
                modelContext.insert(track)
                
                addedTrack = track
            }
        }
    }
    
    /// カタログから正しい曲IDを取得
    private func getCatalogSongId(song: Song) async -> String {
        var catalogSongId = song.id.rawValue
        
        do {
            var searchRequest = MusicCatalogSearchRequest(term: "\(song.title) \(song.artistName)", types: [Song.self])
            searchRequest.limit = 5
            let searchResponse = try await searchRequest.response()
            
            if let catalogSong = searchResponse.songs.first(where: { $0.title == song.title && $0.artistName == song.artistName }) {
                catalogSongId = catalogSong.id.rawValue
            } else if let firstSong = searchResponse.songs.first {
                catalogSongId = firstSong.id.rawValue
            }
        } catch {
            print("Catalog search failed: \(error)")
        }
        
        return catalogSongId
    }
}

// MARK: - SongRow
struct SongRow: View {
    let song: Song
    let onAdd: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            // 曲情報エリア（タップでChorusEditView）
            Button(action: onEdit) {
                HStack {
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 50)
                            .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // +ボタン（タップで直接追加）
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SongSearchView(playlist: Playlist(name: "テスト"))
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}
