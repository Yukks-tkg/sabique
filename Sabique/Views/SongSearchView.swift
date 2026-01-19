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
    @State private var isSearching = false
    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @State private var addedTrack: TrackInPlaylist?
    @State private var showingChorusEdit = false
    
    var body: some View {
        NavigationStack {
            Group {
                if authorizationStatus != .authorized {
                    ContentUnavailableView(
                        "Apple Musicへのアクセスが必要です",
                        systemImage: "music.note",
                        description: Text("設定アプリからApple Musicへのアクセスを許可してください")
                    )
                } else {
                    VStack {
                        // 検索バー
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("曲名またはアーティスト名", text: $searchKeyword)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    Task { await searchMusic() }
                                }
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
                        
                        // 検索結果
                        if isSearching {
                            ProgressView("検索中...")
                                .frame(maxHeight: .infinity)
                        } else if songs.isEmpty && !searchKeyword.isEmpty {
                            ContentUnavailableView.search(text: searchKeyword)
                        } else {
                            List(songs) { song in
                                Button(action: { addSong(song) }) {
                                    SongRow(song: song)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("曲を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    authorizationStatus = await MusicAuthorization.request()
                }
            }
            .sheet(item: $addedTrack, onDismiss: { dismiss() }) { track in
                ChorusEditView(track: track)
            }
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
    
    private func addSong(_ song: Song) {
        let track = TrackInPlaylist(
            appleMusicSongId: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            orderIndex: playlist.tracks.count
        )
        track.playlist = playlist
        modelContext.insert(track)
        
        addedTrack = track
    }
}

// MARK: - SongRow
struct SongRow: View {
    let song: Song
    
    var body: some View {
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
            
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SongSearchView(playlist: Playlist(name: "テスト"))
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}
