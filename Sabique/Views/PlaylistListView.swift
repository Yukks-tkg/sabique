//
//  PlaylistListView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData

struct PlaylistListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]
    
    @State private var showingCreateSheet = false
    @State private var showingSettings = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "プレイリストがありません",
                        systemImage: "music.note.list",
                        description: Text("右上の＋ボタンでプレイリストを作成しましょう")
                    )
                } else {
                    List {
                        ForEach(playlists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                PlaylistRow(playlist: playlist)
                            }
                            .listRowSeparator(.visible, edges: .bottom)
                        }
                        .onDelete(perform: deletePlaylists)
                        .onMove(perform: movePlaylists)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Sabiq")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "line.3.horizontal.circle")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
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
}

// MARK: - PlaylistRow
struct PlaylistRow: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 16) {
            // プレイリストアイコン代わりのビジュアル
            ZStack {
                RoundedRectangle(cornerRadius: 12)
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(playlist.trackCount)曲")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
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
                TextField("プレイリスト名", text: $playlistName)
            }
            .navigationTitle("新規プレイリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成", action: onCreate)
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
