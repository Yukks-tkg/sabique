//
//  SongSearchView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit

/// 曲ソースの種類
enum SongSource: String, CaseIterable, Identifiable {
    case topCharts = "top_charts"
    case topChartsJapan = "top_charts_japan"
    case topChartsUS = "top_charts_us"
    case topChartsUK = "top_charts_uk"
    case topChartsKorea = "top_charts_korea"
    case library = "library"
    case recentlyPlayed = "recently_played"
    
    var id: String { rawValue }
    
    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
    
    /// Storefront ID for country-specific charts
    var storefrontID: String? {
        switch self {
        case .topChartsJapan: return "jp"
        case .topChartsUS: return "us"
        case .topChartsUK: return "gb"
        case .topChartsKorea: return "kr"
        default: return nil
        }
    }
}

struct SongSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let playlist: Playlist
    
    @State private var searchKeyword = ""
    @State private var songs: MusicItemCollection<Song> = []
    @State private var sourceSongs: [Song] = []
    @State private var selectedSource: SongSource = .topCharts
    @State private var isSearching = false
    @State private var isLoadingSource = false
    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @State private var addedTrack: TrackInPlaylist?
    @State private var showingChorusEdit = false
    @State private var searchTask: Task<Void, Never>?
    
    /// 表示する曲リスト（検索中は検索結果、それ以外は選択されたソースの曲）
    private var displayedSongs: [Song] {
        if !searchKeyword.isEmpty {
            return Array(songs)
        } else {
            return sourceSongs
        }
    }
    
    private var sectionTitle: String {
        if !searchKeyword.isEmpty {
            return String(localized: "search_results")
        } else {
            return selectedSource.localizedName
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
                    VStack(spacing: 0) {
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
                        
                        // ソース切り替えセグメントコントロール
                        if searchKeyword.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(SongSource.allCases) { source in
                                        Button(action: {
                                            selectedSource = source
                                        }) {
                                            Text(source.localizedName)
                                                .font(.subheadline)
                                                .fontWeight(selectedSource == source ? .semibold : .regular)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(selectedSource == source ? Color.white.opacity(0.2) : Color.clear)
                                                )
                                                .foregroundColor(selectedSource == source ? .white : .secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                        }
                        
                        // コンテンツ
                        if isSearching || isLoadingSource {
                            ProgressView(isSearching ? String(localized: "searching") : String(localized: "loading"))
                                .frame(maxHeight: .infinity)
                        } else if displayedSongs.isEmpty {
                            if !searchKeyword.isEmpty {
                                ContentUnavailableView.search(text: searchKeyword)
                            } else {
                                ContentUnavailableView(
                                    String(localized: "no_songs_in_source"),
                                    systemImage: "music.note",
                                    description: Text(String(localized: "no_songs_in_source_description"))
                                )
                            }
                        } else {
                            List {
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
                        await loadSongsForSource(selectedSource)
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
            .onChange(of: selectedSource) { oldValue, newValue in
                Task {
                    await loadSongsForSource(newValue)
                }
            }
        }
    }
    
    /// 選択されたソースの曲を読み込む
    private func loadSongsForSource(_ source: SongSource) async {
        isLoadingSource = true
        defer { isLoadingSource = false }
        
        switch source {
        case .recentlyPlayed:
            await loadRecentlyPlayedSongs()
        case .library:
            await loadLibrarySongs()
        case .topCharts:
            await loadTopChartsSongs(storefrontID: nil)
        case .topChartsJapan, .topChartsUS, .topChartsUK, .topChartsKorea:
            await loadTopChartsSongs(storefrontID: source.storefrontID)
        }
    }
    
    /// 最近再生した曲を取得
    private func loadRecentlyPlayedSongs() async {
        do {
            let request = MusicRecentlyPlayedRequest<Song>()
            let response = try await request.response()
            sourceSongs = Array(response.items.prefix(30))
        } catch {
            print("Recently played songs load error: \(error)")
            sourceSongs = []
        }
    }
    
    /// ライブラリの曲を取得
    private func loadLibrarySongs() async {
        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 50
            let response = try await request.response()
            sourceSongs = Array(response.items)
        } catch {
            print("Library songs load error: \(error)")
            sourceSongs = []
        }
    }
    
    /// トップチャートの曲を取得（Storefront指定可能）
    private func loadTopChartsSongs(storefrontID: String?) async {
        do {
            if let storefrontID = storefrontID {
                // Use MusicDataRequest for specific storefront
                let url = URL(string: "https://api.music.apple.com/v1/catalog/\(storefrontID)/charts?types=songs&limit=30")!
                let request = MusicDataRequest(urlRequest: URLRequest(url: url))
                let response = try await request.response()
                
                // Parse JSON response
                let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
                if let results = json?["results"] as? [String: Any],
                   let songs = results["songs"] as? [[String: Any]],
                   let firstChart = songs.first,
                   let data = firstChart["data"] as? [[String: Any]] {
                    
                    // Fetch songs by IDs
                    let songIDs = data.compactMap { $0["id"] as? String }
                    var catalogRequest = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: songIDs.compactMap { MusicItemID($0) })
                    catalogRequest.limit = 30
                    let catalogResponse = try await catalogRequest.response()
                    
                    // Maintain order from chart
                    var orderedSongs: [Song] = []
                    for id in songIDs {
                        if let song = catalogResponse.items.first(where: { $0.id.rawValue == id }) {
                            orderedSongs.append(song)
                        }
                    }
                    sourceSongs = orderedSongs
                } else {
                    sourceSongs = []
                }
            } else {
                // Default: use user's storefront
                let request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [Song.self])
                let response = try await request.response()
                if let songChart = response.songCharts.first {
                    sourceSongs = Array(songChart.items.prefix(30))
                } else {
                    sourceSongs = []
                }
            }
        } catch {
            print("Top charts songs load error: \(error)")
            sourceSongs = []
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
