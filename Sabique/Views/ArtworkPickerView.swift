//
//  ArtworkPickerView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit

struct ArtworkPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // User Settings for Custom Background
    @AppStorage("customBackgroundSongId") private var customBackgroundSongId: String = ""
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""
    @AppStorage("customBackgroundSongTitle") private var customBackgroundSongTitle: String = ""
    @AppStorage("customBackgroundArtistName") private var customBackgroundArtistName: String = ""
    
    @State private var searchKeyword = ""
    @State private var songs: MusicItemCollection<Song> = []
    @State private var sourceSongs: [Song] = []
    @State private var selectedSource: SongSource = .topCharts
    @State private var isSearching = false
    @State private var isLoadingSource = false
    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @State private var searchTask: Task<Void, Never>?
    
    /// Displayed song list
    private var displayedSongs: [Song] {
        if !searchKeyword.isEmpty {
            return Array(songs)
        } else {
            return sourceSongs
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
                        // Search Bar
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
                        
                        // Source Segment
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
                        
                        // Content
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
                                    Button(action: { selectSong(song) }) {
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
                                            
                                            if customBackgroundSongId == song.id.rawValue {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
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
            .navigationTitle(String(localized: "select_background_artwork"))
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
            .onChange(of: searchKeyword) { oldValue, newValue in
                searchTask?.cancel()
                if newValue.isEmpty {
                    songs = []
                    return
                }
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
    
    // MARK: - Logic (Duplicated from SongSearchView, simplified)
    
    private func loadSongsForSource(_ source: SongSource) async {
        isLoadingSource = true
        defer { isLoadingSource = false }
        
        switch source {
        case .recentlyPlayed:
            await loadRecentlyPlayedSongs()
        case .library:
            await loadLibrarySongs()
        case .topCharts:
            await loadTopChartsSongs()
        }
    }
    
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
    
    private func loadTopChartsSongs() async {
        do {
            let request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [Song.self])
            let response = try await request.response()
            if let songChart = response.songCharts.first {
                sourceSongs = Array(songChart.items.prefix(30))
            } else {
                sourceSongs = []
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
            print("Search error: \(error)")
        }
    }
    
    private func selectSong(_ song: Song) {
        // Save ID
        customBackgroundSongId = song.id.rawValue
        
        // Save Title and Artist
        customBackgroundSongTitle = song.title
        customBackgroundArtistName = song.artistName
        
        // Save Artwork URL (High quality)
        if let artwork = song.artwork {
            // Using a reasonably high resolution for background (e.g. 600x600 or device dependent if needed)
            // But usually 600-800 is plenty for a blurred background.
            if let url = artwork.url(width: 800, height: 800) {
                customBackgroundArtworkURLString = url.absoluteString
            }
        }
        
        dismiss()
    }
}

#Preview {
    ArtworkPickerView()
}
