//
//  CommunityView.swift
//  Sabique
//
//  コミュニティプレイリスト一覧画面
//

import SwiftUI
import MusicKit

struct CommunityView: View {
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedFilter: SortOption = .popular
    @State private var showingPublish = false
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""
    @State private var backgroundArtworkURL: URL?
    @State private var searchText = ""
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                backgroundView

                // オーバーレイ
                if backgroundArtworkURL != nil {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                }

                // メインコンテンツ
                mainContent
            }
            .navigationTitle(String(localized: "community"))
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
                await loadAllPlaylists()
            }
            .task(id: customBackgroundArtworkURLString) {
                updateBackgroundURL()
            }
            .onAppear {
                updateBackgroundURL()
            }
            .refreshable {
                await loadAllPlaylists()
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

    private func updateBackgroundURL() {
        if !customBackgroundArtworkURLString.isEmpty, let url = URL(string: customBackgroundArtworkURLString) {
            backgroundArtworkURL = url
        } else {
            backgroundArtworkURL = nil
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // 検索バー
            searchBar

            // 検索中はリスト表示、それ以外はスワイプ切り替え
            if isSearching {
                // 検索結果表示
                if communityManager.isLoading {
                    loadingView
                } else if communityManager.playlists.isEmpty {
                    emptyView
                } else {
                    playlistList
                }
            } else {
                // タブ切り替え（スワイプ対応）
                swipeableTabContent
            }
        }
    }

    private var swipeableTabContent: some View {
        VStack(spacing: 0) {
            // タブヘッダー
            filterPicker

            // スワイプ可能なTabView（両方のリストを事前読み込み）
            TabView(selection: $selectedFilter) {
                // 人気タブ
                popularTabContent
                    .tag(SortOption.popular)

                // 新着タブ
                newestTabContent
                    .tag(SortOption.newest)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    @ViewBuilder
    private var popularTabContent: some View {
        if communityManager.isLoadingPopular && communityManager.popularPlaylists.isEmpty {
            loadingView
        } else if communityManager.popularPlaylists.isEmpty {
            emptyView
        } else {
            playlistListView(for: communityManager.popularPlaylists)
        }
    }

    @ViewBuilder
    private var newestTabContent: some View {
        if communityManager.isLoadingNewest && communityManager.newestPlaylists.isEmpty {
            loadingView
        } else if communityManager.newestPlaylists.isEmpty {
            emptyView
        } else {
            playlistListView(for: communityManager.newestPlaylists)
        }
    }

    private func playlistListView(for playlists: [CommunityPlaylist]) -> some View {
        let filtered = playlists.filter { !BlockManager.shared.isBlocked(userId: $0.authorId) }
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filtered) { playlist in
                    NavigationLink(destination: CommunityPlaylistDetailView(playlist: playlist)) {
                        CommunityPlaylistCard(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(String(localized: "search_highlight_lists"), text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    Task {
                        if newValue.isEmpty {
                            isSearching = false
                            await loadPlaylists()
                        } else {
                            isSearching = true
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待つ
                            if searchText == newValue {
                                try? await communityManager.searchPlaylists(keyword: newValue)
                            }
                        }
                    }
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isSearching = false
                    Task {
                        await loadPlaylists()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterPicker: some View {
        Picker(String(localized: "sort_by"), selection: $selectedFilter) {
            Text(String(localized: "popular_tab")).tag(SortOption.popular)
            Text(String(localized: "newest_tab")).tag(SortOption.newest)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: "loading"))
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
                String(localized: "no_highlight_lists"),
                systemImage: "music.note.list",
                description: Text(String(localized: "be_first_to_post"))
            )
            Spacer()
        }
    }

    private var playlistList: some View {
        let filtered = communityManager.playlists.filter { !BlockManager.shared.isBlocked(userId: $0.authorId) }
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filtered) { playlist in
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

    private func loadAllPlaylists() async {
        do {
            try await communityManager.fetchAllPlaylists(limit: 20)
        } catch {
            print("プレイリスト読み込みエラー: \(error)")
        }
    }

    private func loadPlaylists() async {
        do {
            try await communityManager.fetchPlaylists(sortBy: selectedFilter, limit: 20)
        } catch {
            print("プレイリスト読み込みエラー: \(error)")
        }
    }

}

// MARK: - CommunityPlaylistCard

struct CommunityPlaylistCard: View {
    let playlist: CommunityPlaylist
    @State private var artworkURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // アートワーク
                artworkView

                VStack(alignment: .leading, spacing: 4) {
                    // プレイリスト名
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(2)

                    // 投稿者
                    Group {
                        if let countryCode = playlist.authorCountryCode, !countryCode.isEmpty {
                            Text("by \(playlist.authorName ?? "匿名") \(flagEmoji(for: countryCode))")
                        } else {
                            Text("by \(playlist.authorName ?? "匿名")")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // 曲数
                    Text(String(localized: "track_count_\(playlist.tracks.count)"))
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
                    Text(String(localized: "popular_badge"))
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
        .task {
            await loadArtwork()
        }
    }

    private var artworkView: some View {
        Group {
            if let url = artworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderArtwork
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                placeholderArtwork
            }
        }
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

    private func loadArtwork() async {
        guard let firstTrack = playlist.tracks.first else { return }

        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                let url = artwork.url(width: 120, height: 120)
                await MainActor.run {
                    artworkURL = url
                }
            }
        } catch {
            print("アートワーク取得エラー: \(error)")
        }
    }

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicodeScalar = UnicodeScalar(base + scalar.value) {
                emoji.append(String(unicodeScalar))
            }
        }
        return emoji
    }
}

#Preview {
    CommunityView()
        .environmentObject(CommunityManager())
        .environmentObject(AuthManager())
}
