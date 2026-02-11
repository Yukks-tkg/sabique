//
//  PublishPlaylistView.swift
//  Sabique
//
//  プレイリストをコミュニティに投稿する画面
//

import SwiftUI
import SwiftData
import FirebaseAuth
import AuthenticationServices
import MusicKit

struct PublishPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var storeManager: StoreManager

    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]

    // 外部から指定されたプレイリスト（PlaylistDetailViewから開く場合）
    var preselectedPlaylist: Playlist?

    @State private var selectedPlaylist: Playlist?
    @State private var isPublishing = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if authManager.isSignedIn {
                    playlistSelectionView
                } else {
                    signInPromptView
                }
            }
            .navigationTitle(String(localized: "publish_highlight_list"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                if authManager.isSignedIn && selectedPlaylist != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "publish")) {
                            publishPlaylist()
                        }
                        .disabled(isPublishing)
                    }
                }
            }
            .alert(String(localized: "publish_complete"), isPresented: $showingSuccess) {
                Button(String(localized: "ok")) {
                    dismiss()
                }
            } message: {
                Text(String(localized: "highlight_list_published"))
            }
            .alert(String(localized: "error"), isPresented: $showingError) {
                Button(String(localized: "ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // preselectedPlaylistが指定されていれば自動選択
                if let preselected = preselectedPlaylist {
                    selectedPlaylist = preselected
                }
            }
        }
    }

    // MARK: - Subviews

    var playlistSelectionView: some View {
        List {
            Section {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        String(localized: "no_highlight_lists"),
                        systemImage: "music.note.list",
                        description: Text(String(localized: "create_highlight_list_first"))
                    )
                } else {
                    ForEach(playlists) { playlist in
                        PlaylistSelectionRow(
                            playlist: playlist,
                            isSelected: selectedPlaylist?.id == playlist.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPlaylist = playlist
                        }
                    }
                }
            } header: {
                Text(String(localized: "select_highlight_list_to_publish"))
            } footer: {
                if let selected = selectedPlaylist {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "selected_\(selected.name)"))
                            .font(.subheadline)
                            .bold()
                        Text(String(localized: "contains_tracks_\(selected.trackCount)"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }

            if isPublishing {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        }
    }

    var signInPromptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(String(localized: "please_sign_in"))
                .font(.headline)

            Text(String(localized: "sign_in_to_publish"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Apple Sign Inボタン
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    let nonce = authManager.generateNonce()
                    request.requestedScopes = []  // 本名は要求しない
                    request.nonce = authManager.sha256(nonce)
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            do {
                                try await authManager.signInWithApple(authorization: authorization)
                            } catch {
                                print("❌ サインインエラー: \(error)")
                            }
                        }
                    case .failure(let error):
                        print("❌ Apple Sign In エラー: \(error)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }

    // MARK: - Actions

    private func publishPlaylist() {
        guard let playlist = selectedPlaylist else { return }
        guard let userId = authManager.currentUser?.uid else { return }

        // 最低トラック数チェック
        guard playlist.trackCount >= FreeTierLimits.minTracksForPublish else {
            errorMessage = "投稿には最低\(FreeTierLimits.minTracksForPublish)曲必要です"
            showingError = true
            return
        }

        // 最大トラック数チェック
        let maxTracks = storeManager.isPremium ? FreeTierLimits.maxTracksForPublishPremium : FreeTierLimits.maxTracksPerPlaylist
        guard playlist.trackCount <= maxTracks else {
            if storeManager.isPremium {
                errorMessage = "投稿できるのは最大\(maxTracks)曲までです"
            } else {
                errorMessage = "無料版では最大\(maxTracks)曲まで投稿できます。プレミアムにアップグレードすると\(FreeTierLimits.maxTracksForPublishPremium)曲まで投稿可能です"
            }
            showingError = true
            return
        }

        // 全てのトラックにハイライトが設定されているかチェック
        guard playlist.allTracksHaveChorus else {
            errorMessage = "全ての曲にハイライト区間を設定してください"
            showingError = true
            return
        }

        isPublishing = true

        Task {
            do {
                // ユーザープロフィールを取得してニックネームを使用
                let userProfile = try await communityManager.getUserProfile(userId: userId)
                let authorName = userProfile.nickname ?? authManager.currentUser?.displayName

                // デバッグログ
                print("🔍 投稿時のプロフィール情報:")
                print("  - userId: \(userId)")
                print("  - nickname: \(userProfile.nickname ?? "nil")")
                print("  - displayName: \(authManager.currentUser?.displayName ?? "nil")")
                print("  - authorName（投稿に使用）: \(authorName ?? "nil")")

                try await communityManager.publishPlaylist(
                    playlist: playlist,
                    authorId: userId,
                    authorName: authorName,
                    authorIsPremium: storeManager.isPremium,
                    authorCountryCode: userProfile.countryCode,
                    authorArtworkURL: userProfile.profileArtworkURL
                )

                // 一覧を更新
                try? await communityManager.fetchPlaylists(sortBy: .newest, limit: 20)

                await MainActor.run {
                    isPublishing = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - PlaylistSelectionRow

struct PlaylistSelectionRow: View {
    let playlist: Playlist
    let isSelected: Bool

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
                    placeholderArtwork
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                placeholderArtwork
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                Text(String(localized: "track_count_\(playlist.trackCount)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 選択時のみチェックマークを右側に表示
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadArtwork()
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
                .frame(width: 50, height: 50)

            Image(systemName: "music.note.list")
                .foregroundColor(.white.opacity(0.8))
                .font(.title3)
        }
    }

    private func loadArtwork() async {
        // 最初のトラックのアートワークを取得
        guard let firstTrack = playlist.sortedTracks.first else { return }

        // キャッシュがあればそれを使用
        if let cachedURL = firstTrack.artworkURL {
            artworkURL = cachedURL
            return
        }

        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                let url = artwork.url(width: 100, height: 100)
                await MainActor.run {
                    artworkURL = url
                    firstTrack.artworkURL = url // キャッシュに保存
                }
            }
        } catch {
            print("アートワーク取得エラー: \(error)")
        }
    }
}

#Preview {
    PublishPlaylistView()
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
        .environmentObject(AuthManager())
        .environmentObject(CommunityManager())
        .environmentObject(StoreManager())
}
