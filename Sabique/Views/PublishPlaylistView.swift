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

struct PublishPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var storeManager: StoreManager

    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]

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
            .navigationTitle("プレイリストを投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                if authManager.isSignedIn && selectedPlaylist != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("投稿") {
                            publishPlaylist()
                        }
                        .disabled(isPublishing)
                    }
                }
            }
            .alert("投稿完了", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("プレイリストをコミュニティに投稿しました！")
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    var playlistSelectionView: some View {
        List {
            Section {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "プレイリストがありません",
                        systemImage: "music.note.list",
                        description: Text("まずはプレイリストを作成してください")
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
                Text("投稿するプレイリストを選択")
            } footer: {
                if let selected = selectedPlaylist {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("選択中: \(selected.name)")
                            .font(.subheadline)
                            .bold()
                        Text("\(selected.trackCount)曲が含まれます")
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
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("サインインが必要です")
                .font(.headline)

            Text("プレイリストを投稿するにはApple IDでサインインしてください")
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
            .signInWithAppleButtonStyle(.black)
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

                try await communityManager.publishPlaylist(
                    playlist: playlist,
                    authorId: userId,
                    authorName: authorName,
                    authorIsPremium: storeManager.isPremium
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

    var body: some View {
        HStack(spacing: 12) {
            // チェックマーク
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                Text("\(playlist.trackCount)曲")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PublishPlaylistView()
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
        .environmentObject(AuthManager())
        .environmentObject(CommunityManager())
        .environmentObject(StoreManager())
}
