//
//  CommunityView.swift
//  Sabique
//
//  コミュニティプレイリスト一覧画面
//

import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedFilter: SortOption = .popular
    @State private var showingPublish = false
    @State private var backgroundArtworkURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                backgroundView

                // オーバーレイ
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                // メインコンテンツ
                mainContent
            }
            .navigationTitle("みんなのプレイリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingPublish = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                }
            }
            .task {
                await loadPlaylists()
                await updateBackgroundArtwork()
            }
            .refreshable {
                await loadPlaylists()
            }
            .sheet(isPresented: $showingPublish) {
                PublishPlaylistView()
            }
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
                .id(url)
                .transition(.opacity)
            } else {
                Color(.systemBackground)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: backgroundArtworkURL)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // フィルター切り替え
            filterPicker

            if communityManager.isLoading {
                loadingView
            } else if communityManager.playlists.isEmpty {
                emptyView
            } else {
                playlistList
            }
        }
    }

    private var filterPicker: some View {
        Picker("並び替え", selection: $selectedFilter) {
            Text("🔥 人気").tag(SortOption.popular)
            Text("✨ 新着").tag(SortOption.newest)
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: selectedFilter) { _, _ in
            Task {
                await loadPlaylists()
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "プレイリストがありません",
                systemImage: "music.note.list",
                description: Text("最初の投稿者になりましょう！")
            )
            Spacer()
        }
    }

    private var playlistList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(communityManager.playlists) { playlist in
                    NavigationLink(destination: CommunityPlaylistDetailView(playlist: playlist)) {
                        CommunityPlaylistCard(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadPlaylists() async {
        do {
            try await communityManager.fetchPlaylists(sortBy: selectedFilter, limit: 20)
        } catch {
            print("プレイリスト読み込みエラー: \(error)")
        }
    }

    private func updateBackgroundArtwork() async {
        guard let firstPlaylist = communityManager.playlists.first,
              !firstPlaylist.tracks.isEmpty else {
            return
        }

        // TODO: MusicKitで実際のアートワークURLを取得
        // 仮でダミーURLを設定（後で実装）
    }
}

// MARK: - CommunityPlaylistCard

struct CommunityPlaylistCard: View {
    let playlist: CommunityPlaylist

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // アートワーク（仮）
                placeholderArtwork

                VStack(alignment: .leading, spacing: 4) {
                    // プレイリスト名
                    HStack {
                        Text(playlist.name)
                            .font(.headline)
                            .lineLimit(2)

                        if playlist.authorIsPremium {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }

                    // 投稿者
                    Text("by \(playlist.authorName ?? "匿名")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 曲数
                    Text("\(playlist.tracks.count)曲")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    // いいね数
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("\(playlist.likeCount)")
                    }
                    .font(.caption)

                    // ダウンロード数
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("\(playlist.downloadCount)")
                    }
                    .font(.caption)
                }
            }

            // バッジ
            if playlist.likeCount >= 100 {
                HStack {
                    Text("🔥 人気")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)

            Image(systemName: "music.note.list")
                .foregroundColor(.blue)
                .font(.title3)
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(CommunityManager())
        .environmentObject(AuthManager())
}
