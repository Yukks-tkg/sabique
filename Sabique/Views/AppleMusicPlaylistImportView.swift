//
//  AppleMusicPlaylistImportView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit

struct AppleMusicPlaylistImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: StoreManager

    @State private var libraryPlaylists: [MusicKit.Playlist] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPlaylist: MusicKit.Playlist?
    @State private var isImporting = false
    @State private var importCancelled = false
    @State private var importProgress: (current: Int, total: Int) = (0, 0)
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var importedPlaylist: Playlist?

    let onImport: (Playlist) -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(String(localized: "loading_playlists"))
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        String(localized: "error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if libraryPlaylists.isEmpty {
                    ContentUnavailableView(
                        String(localized: "no_playlists"),
                        systemImage: "music.note.list",
                        description: Text(String(localized: "no_playlists_in_library"))
                    )
                } else {
                    List(libraryPlaylists) { playlist in
                        Button(action: { selectPlaylist(playlist) }) {
                            HStack(spacing: 12) {
                                // アートワーク
                                if let artwork = playlist.artwork {
                                    ArtworkImage(artwork, width: 50)
                                        .cornerRadius(6)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "music.note.list")
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let description = playlist.curatorName {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(isImporting)
                    }
                }
            }
            .navigationTitle(String(localized: "select_from_apple_music"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .task {
                await loadPlaylists()
            }
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 16) {
                            ProgressView()
                            Text(String(localized: "importing"))
                                .font(.headline)
                            if importProgress.total > 0 {
                                Text("\(importProgress.current) / \(importProgress.total)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Button(action: { importCancelled = true }) {
                                Text(String(localized: "cancel"))
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(24)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    }
                    .ignoresSafeArea()
                }
            }
            .alert(String(localized: "import_complete"), isPresented: $showingImportResult) {
                Button(String(localized: "ok")) {
                    if let playlist = importedPlaylist {
                        onImport(playlist)
                    }
                    dismiss()
                }
            } message: {
                Text(importResultMessage)
            }
        }
    }

    private func loadPlaylists() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // ライブラリへのアクセス権限を確認
            let status = await MusicAuthorization.request()
            guard status == .authorized else {
                errorMessage = "Apple Musicへのアクセスが許可されていません"
                isLoading = false
                return
            }
            
            // ライブラリからプレイリストを取得
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.sort(by: \.lastPlayedDate, ascending: false)
            let response = try await request.response()
            
            libraryPlaylists = Array(response.items)
            isLoading = false
        } catch {
            errorMessage = "プレイリストの読み込みに失敗しました: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func selectPlaylist(_ playlist: MusicKit.Playlist) {
        Task {
            await importPlaylist(playlist)
        }
    }
    
    private func importPlaylist(_ musicPlaylist: MusicKit.Playlist) async {
        isImporting = true
        importCancelled = false
        importProgress = (0, 0)

        do {
            // プレイリストの詳細（曲リスト）を取得
            let detailedPlaylist = try await musicPlaylist.with([.tracks])

            guard let tracks = detailedPlaylist.tracks else {
                isImporting = false
                return
            }

            // 無料版は曲数制限
            let maxTracks = storeManager.isPremium ? tracks.count : FreeTierLimits.maxTracksPerPlaylist
            let tracksToImport = Array(tracks.prefix(maxTracks))
            let skippedCount = max(0, tracks.count - maxTracks)

            await MainActor.run {
                importProgress = (0, tracksToImport.count)
            }

            // 新しいプレイリストを作成
            let newPlaylist = Playlist(name: musicPlaylist.name, orderIndex: 0)
            modelContext.insert(newPlaylist)

            // 曲をインポート
            var importIndex = 0
            for track in tracksToImport {
                // キャンセルチェック
                if importCancelled {
                    // インポート途中のプレイリストを削除
                    modelContext.delete(newPlaylist)
                    await MainActor.run {
                        isImporting = false
                    }
                    return
                }

                // TrackタイトルでカタログからSongを検索して正しいIDを取得
                var searchRequest = MusicCatalogSearchRequest(term: "\(track.title) \(track.artistName)", types: [Song.self])
                searchRequest.limit = 1

                if let searchResponse = try? await searchRequest.response(),
                   let song = searchResponse.songs.first {
                    let trackInPlaylist = TrackInPlaylist(
                        appleMusicSongId: song.id.rawValue,
                        title: song.title,
                        artist: song.artistName,
                        orderIndex: importIndex
                    )
                    trackInPlaylist.playlist = newPlaylist
                    modelContext.insert(trackInPlaylist)
                    importIndex += 1
                }

                await MainActor.run {
                    importProgress = (importIndex, tracksToImport.count)
                }
            }

            await MainActor.run {
                isImporting = false
                importedPlaylist = newPlaylist
                if skippedCount > 0 {
                    importResultMessage = String(format: NSLocalizedString("import_limited_message", comment: ""), importIndex, skippedCount)
                    showingImportResult = true
                } else {
                    onImport(newPlaylist)
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                isImporting = false
                errorMessage = "インポートに失敗しました: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    AppleMusicPlaylistImportView { _ in }
}
