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
    
    @StateObject private var playerManager = ChorusPlayerManager()
    
    var body: some View {
        List {
            // 再生セクション
            if !playlist.sortedTracks.isEmpty {
                Section {
                    Button(action: startPlayback) {
                        HStack {
                            Image(systemName: playerManager.isPlaying ? "stop.fill" : "play.fill")
                            Text(playerManager.isPlaying ? "停止" : "サビを連続再生")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: playerManager.isPlaying ? [.red, .orange] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .padding()
                }
                .listRowBackground(Color.clear)
            }
            
            // 曲リスト
            Section("曲リスト") {
                if playlist.sortedTracks.isEmpty {
                    Text("曲がありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(playlist.sortedTracks) { track in
                        TrackRow(track: track)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTrack = track
                                showingChorusEdit = true
                            }
                    }
                    .onDelete(perform: deleteTracks)
                }
            }
        }
        .navigationTitle(playlist.name)
        .toolbar {
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
}

// MARK: - TrackRow
struct TrackRow: View {
    let track: TrackInPlaylist
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("サビ設定済み")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("\(track.chorusStartFormatted) - \(track.chorusEndFormatted)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            } else {
                Text("通常再生")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
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
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(track.appleMusicSongId)
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

#Preview {
    NavigationStack {
        PlaylistDetailView(playlist: Playlist(name: "テストプレイリスト"))
    }
    .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}
