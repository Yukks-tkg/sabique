//
//  CommunityPlaylistDetailView.swift
//  Sabique
//
//  コミュニティプレイリスト詳細画面
//

import SwiftUI
import SwiftData
import MusicKit

struct CommunityPlaylistDetailView: View {
    let playlist: CommunityPlaylist

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var hasLiked = false
    @State private var currentLikeCount: Int
    @State private var currentDownloadCount: Int
    @State private var artworkURL: URL?
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var showingReport = false
    @State private var errorMessage = ""

    init(playlist: CommunityPlaylist) {
        self.playlist = playlist
        _currentLikeCount = State(initialValue: playlist.likeCount)
        _currentDownloadCount = State(initialValue: playlist.downloadCount)
        // いいね状態を読み込み
        _hasLiked = State(initialValue: LikeManager.shared.hasLiked(playlistId: playlist.id ?? ""))
    }

    var body: some View {
        ZStack {
            // ダイナミック背景: アートワークをぼかして配置
            GeometryReader { geometry in
                if let url = artworkURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .blur(radius: 50)
                            .opacity(0.6)
                    } placeholder: {
                        Color(.systemGroupedBackground)
                    }
                } else {
                    Color(.systemGroupedBackground)
                }
            }
            .ignoresSafeArea()

            // 背景のオーバーレイ（視認性を確保）
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダー
                    headerSection

                    // アクションボタン
                    actionButtons

                    // トラック一覧
                    trackList
                }
                .padding()
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingReport = true }) {
                        Label("不適切な内容を報告", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingReport) {
            ReportPlaylistView(playlist: playlist)
        }
        .alert("インポート完了", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("プレイリストをマイプレイリストに追加しました")
        }
        .alert("エラー", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            // アートワーク
            artworkView
                .frame(width: 200, height: 200)
                .task {
                    await loadArtwork()
                }

            // 統計情報
            HStack(spacing: 30) {
                VStack {
                    Text("\(currentLikeCount)")
                        .font(.title2)
                        .bold()
                    Text("いいね")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(currentDownloadCount)")
                        .font(.title2)
                        .bold()
                    Text("利用数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(playlist.tracks.count)")
                        .font(.title2)
                        .bold()
                    Text("曲")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 投稿者
            HStack {
                Text("by \(playlist.authorName ?? "匿名")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if playlist.authorIsPremium {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }

            // 投稿日
            Text(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // インポートボタン
            Button(action: { importPlaylist() }) {
                Label("インポート", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            // いいねボタン
            Button(action: { toggleLike() }) {
                Image(systemName: hasLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(hasLiked ? .pink : .white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }

    private var trackList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("収録曲")
                .font(.headline)

            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                HStack {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.subheadline)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // サビ区間
                    if let start = track.chorusStart, let end = track.chorusEnd {
                        Text("\(formatTime(start)) - \(formatTime(end))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artworkURL = artworkURL {
            AsyncImage(url: artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .cornerRadius(16)
            } placeholder: {
                placeholderArtwork
            }
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note.list")
                .foregroundColor(.blue)
                .font(.system(size: 60))
        }
    }

    // MARK: - Actions

    private func importPlaylist() {
        // 即座にUI更新（楽観的更新）
        currentDownloadCount += 1

        Task {
            do {
                try await communityManager.importPlaylist(
                    communityPlaylist: playlist,
                    modelContext: modelContext
                )
                await MainActor.run {
                    showingImportSuccess = true
                }
            } catch {
                // エラーが発生したら利用数を戻す
                await MainActor.run {
                    currentDownloadCount -= 1
                    errorMessage = error.localizedDescription
                    showingImportError = true
                }
            }
        }
    }

    private func toggleLike() {
        // まだいいねしていない場合のみ
        guard !hasLiked, let playlistId = playlist.id else { return }

        // 即座にUI更新（楽観的更新）
        hasLiked = true
        currentLikeCount += 1

        // UserDefaultsに保存
        LikeManager.shared.addLike(playlistId: playlistId)

        // バックグラウンドでFirestoreに保存
        Task {
            await communityManager.incrementLikeCount(playlistId: playlistId)
        }
    }

    private func formatTime(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func loadArtwork() async {
        guard let firstTrack = playlist.tracks.first else { return }

        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicId)
            )
            let response = try await request.response()

            if let song = response.items.first, let artwork = song.artwork {
                let url = artwork.url(width: 400, height: 400)
                await MainActor.run {
                    artworkURL = url
                }
            }
        } catch {
            print("アートワーク取得エラー: \(error)")
        }
    }
}

#Preview {
    let samplePlaylist = CommunityPlaylist(
        id: "sample",
        name: "髭男サビメドレー",
        authorId: "user123",
        authorName: "田中太郎",
        authorIsPremium: true,
        tracks: [
            CommunityTrack(
                id: "1",
                appleMusicId: "123",
                isrc: nil,
                title: "Pretender",
                artist: "Official髭男dism",
                chorusStart: 45.0,
                chorusEnd: 75.0
            )
        ],
        songIds: ["123"],
        likeCount: 42,
        downloadCount: 120,
        createdAt: Date()
    )

    return NavigationStack {
        CommunityPlaylistDetailView(playlist: samplePlaylist)
            .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
            .environmentObject(CommunityManager())
            .environmentObject(AuthManager())
    }
}
