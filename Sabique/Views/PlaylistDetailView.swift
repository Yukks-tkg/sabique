//
//  PlaylistDetailView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import SwiftData
import MusicKit
import AuthenticationServices
import FirebaseAuth

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: StoreManager
    @Bindable var playlist: Playlist
    
    @State private var showingAddSong = false
    @State private var selectedTrack: TrackInPlaylist?
    @State private var showingChorusEdit = false
    @State private var backgroundArtworkURL: URL?
    @State private var showingPaywall = false
    @State private var shouldScrollToBottom = false
    @State private var previousTrackCount = 0
    @State private var showingRenameAlert = false
    @State private var newPlaylistName = ""

    // プレビュー再生
    @State private var previewingTrackId: UUID?
    @State private var isLoadingPreview = false
    @State private var previewTimer: Timer?

    // 投稿関連
    @State private var showingPublishConfirm = false
    @State private var showingSignInSheet = false
    @State private var showingPublishSuccess = false
    @State private var showingPublishError = false
    @State private var publishErrorMessage = ""
    @State private var isPublishing = false

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    
    // 1曲目のID（並べ替え検知用）
    private var firstTrackId: String? {
        playlist.sortedTracks.first?.appleMusicSongId
    }
    
    @StateObject private var playerManager = ChorusPlayerManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundView
            overlayView
            
            // コンテンツ
            contentView
                .task(id: firstTrackId) {
                    await loadFirstTrackArtwork()
                }
            
            // 再生コントロール（下部に固定）
            if !playlist.sortedTracks.isEmpty {
                playbackControlsView
            }
        }
        .navigationTitle(String(localized: "highlight_list"))
        .preferredColorScheme(.dark)
        .toolbar {
            // コミュニティに投稿ボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { handlePublish() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(playlist.sortedTracks.isEmpty || isPublishing)
            }

            // 曲追加ボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { handleAddTrack() }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSong, onDismiss: {
            // トラックが追加されたかチェック
            if playlist.tracks.count > previousTrackCount {
                // 少し遅延させてからスクロール（Listの更新を待つ）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shouldScrollToBottom = true
                }
            }
        }) {
            SongSearchView(playlist: playlist)
                .onAppear {
                    // シート表示時のトラック数を記録
                    previousTrackCount = playlist.tracks.count
                }
        }
        .onDisappear {
            // 画面を離れたらプレビュー再生を停止
            if previewingTrackId != nil {
                stopPreview()
            }
        }
        .sheet(item: $selectedTrack, onDismiss: {
            // ハイライト設定画面から戻ったら再生を停止
            SystemMusicPlayer.shared.stop()
        }) { track in
            ChorusEditView(track: track)
        }
        .sheet(isPresented: $showingSignInSheet) {
            SignInSheetView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert(String(localized: "publish_to_community_confirm"), isPresented: $showingPublishConfirm) {
            publishConfirmAlertButtons
        } message: {
            publishConfirmAlertMessage
        }
        .alert(String(localized: "publish_complete"), isPresented: $showingPublishSuccess) {
            Button(String(localized: "ok"), role: .cancel) { }
        } message: {
            Text(String(localized: "highlight_list_published"))
        }
        .alert(String(localized: "error"), isPresented: $showingPublishError) {
            Button(String(localized: "ok"), role: .cancel) { }
        } message: {
            Text(publishErrorMessage)
        }
        .alert(String(localized: "rename_list"), isPresented: $showingRenameAlert) {
            renameAlertContent
        }
    }

    // MARK: - Background Views

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

    private var overlayView: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        if playlist.sortedTracks.isEmpty {
            emptyContentView
        } else {
            trackListView
        }
    }

    private var emptyContentView: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                String(localized: "no_songs"),
                systemImage: "music.note",
                description: Text(String(localized: "no_songs_description"))
            )
            addTrackButton
        }
    }

    private var addTrackButton: some View {
        Button(action: { handleAddTrack() }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text(String(localized: "add_track"))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
        }
    }

    private var trackListView: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    trackListContent
                    addTrackListButton
                } header: {
                    sectionHeader
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
            .onChange(of: shouldScrollToBottom) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("addButton", anchor: .bottom)
                    }
                    shouldScrollToBottom = false
                }
            }
        }
    }

    private var trackListContent: some View {
        ForEach(playlist.sortedTracks) { track in
            trackRowView(for: track)
        }
        .onDelete(perform: deleteTracks)
        .onMove(perform: moveTracks)
    }

    private func trackRowView(for track: TrackInPlaylist) -> some View {
        let isCurrentlyPlaying = playerManager.isPlaying && playerManager.currentTrack?.id == track.id
        let isPreviewing = previewingTrackId == track.id
        let isHighlighted = isCurrentlyPlaying || isPreviewing
        return TrackRow(
            track: track,
            isPlaying: isCurrentlyPlaying || isPreviewing,
            onArtworkTap: { previewTrack(track) }
        )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHighlighted ? Color.white.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                // プレビュー再生中なら停止
                if previewingTrackId != nil {
                    stopPreview()
                }
                if playerManager.isPlaying {
                    playerManager.stop()
                }
                selectedTrack = track
                showingChorusEdit = true
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .listRowBackground(Color.clear)
            .id(track.id)
    }

    private var addTrackListButton: some View {
        Button(action: { handleAddTrack() }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text(String(localized: "add_track"))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .id("addButton")
    }

    private func previewTrack(_ track: TrackInPlaylist) {
        // 同じ曲をタップしたら停止
        if previewingTrackId == track.id {
            stopPreview()
            return
        }

        // ChorusPlayerManagerが再生中なら停止
        if playerManager.isPlaying {
            playerManager.stop()
        }

        // 前回のプレビューを停止
        stopPreview()

        previewingTrackId = track.id
        isLoadingPreview = true

        Task {
            do {
                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(track.appleMusicSongId)
                )
                let response = try await request.response()

                guard let song = response.items.first else {
                    await MainActor.run {
                        isLoadingPreview = false
                        previewingTrackId = nil
                    }
                    return
                }

                let player = SystemMusicPlayer.shared
                player.queue = [song]
                try await player.play()

                // ハイライト区間があればシーク
                if let chorusStart = track.chorusStartSeconds {
                    player.playbackTime = chorusStart
                }

                await MainActor.run {
                    isLoadingPreview = false

                    // 終了位置が設定されている場合はタイマーで監視
                    if let chorusEnd = track.chorusEndSeconds {
                        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            let currentTime = SystemMusicPlayer.shared.playbackTime
                            if currentTime >= chorusEnd {
                                stopPreview()
                            }
                        }
                    }
                }
            } catch {
                print("プレビュー再生エラー: \(error)")
                await MainActor.run {
                    isLoadingPreview = false
                    previewingTrackId = nil
                }
            }
        }
    }

    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        SystemMusicPlayer.shared.stop()
        previewingTrackId = nil
    }

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Text(playlist.name)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.primary)

            Button(action: {
                newPlaylistName = playlist.name
                showingRenameAlert = true
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Alert Helpers

    @ViewBuilder
    private var publishConfirmAlertButtons: some View {
        Button(String(localized: "cancel"), role: .cancel) { }
        Button(String(localized: "publish")) {
            publishPlaylist()
        }
    }

    private var publishConfirmAlertMessage: Text {
        Text(String(localized: "publish_message_\(playlist.name)"))
    }

    @ViewBuilder
    private var renameAlertContent: some View {
        TextField(String(localized: "list_name"), text: $newPlaylistName)
            .onChange(of: newPlaylistName) { _, newValue in
                if newValue.count > PlaylistValidator.maxNameLength {
                    newPlaylistName = String(newValue.prefix(PlaylistValidator.maxNameLength))
                }
            }
        Button(String(localized: "cancel"), role: .cancel) { }
        Button(String(localized: "save")) {
            let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespaces)
            if !trimmedName.isEmpty {
                playlist.name = trimmedName
            }
        }
    }
    
    /// トラック追加制限をチェック
    private var canAddTrack: Bool {
        storeManager.isPremium || playlist.trackCount < FreeTierLimits.maxTracksPerPlaylist
    }

    // MARK: - Playback Controls

    private var playbackControlsView: some View {
        VStack(spacing: 0) {
            playbackGradient
            playbackButtons
        }
        .frame(maxWidth: .infinity)
        .animation(nil, value: playerManager.isPlaying)
    }

    private var playbackGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.clear, location: 0.0),
                .init(color: Color.black.opacity(0.1), location: 0.3),
                .init(color: Color.black.opacity(0.4), location: 0.6),
                .init(color: Color.black.opacity(0.7), location: 0.85),
                .init(color: Color.black.opacity(0.8), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 60)
    }

    private var playbackButtons: some View {
        HStack(spacing: 20) {
            previousButton
            playStopButton
            nextButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }

    /// ハイライト再生またはプレビュー再生のいずれかが再生中か
    private var isAnyPlaying: Bool {
        playerManager.isPlaying || previewingTrackId != nil
    }

    private var previousButton: some View {
        Button(action: { handlePrevious() }) {
            Image(systemName: "backward.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.2))
                .cornerRadius(14)
        }
        .disabled(!isAnyPlaying)
        .opacity(isAnyPlaying ? 1.0 : 0.4)
    }

    private var playStopButton: some View {
        Button(action: handlePlayStop) {
            HStack(spacing: 12) {
                Image(systemName: isAnyPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
                Text(isAnyPlaying ? String(localized: "stop") : String(localized: "play"))
                    .font(.headline)
                    .bold()
            }
            .foregroundColor(.white)
            .frame(width: 160)
            .padding(.vertical, 16)
            .background(playButtonGradient)
            .cornerRadius(16)
            .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var playButtonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.4)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var nextButton: some View {
        Button(action: { handleNext() }) {
            Image(systemName: "forward.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.2))
                .cornerRadius(14)
        }
        .disabled(!isAnyPlaying)
        .opacity(isAnyPlaying ? 1.0 : 0.4)
    }

    // MARK: - Actions

    /// トラック追加ボタンの処理
    private func handleAddTrack() {
        if canAddTrack {
            showingAddSong = true
        } else {
            showingPaywall = true
        }
    }

    /// 投稿ボタンの処理
    private func handlePublish() {
        // サインインチェック
        guard authManager.isSignedIn else {
            showingSignInSheet = true
            return
        }

        // バリデーション
        if playlist.trackCount < FreeTierLimits.minTracksForPublish {
            publishErrorMessage = "投稿には最低\(FreeTierLimits.minTracksForPublish)曲必要です"
            showingPublishError = true
            return
        }

        let maxTracks = storeManager.isPremium ? FreeTierLimits.maxTracksForPublishPremium : FreeTierLimits.maxTracksPerPlaylist
        if playlist.trackCount > maxTracks {
            if storeManager.isPremium {
                publishErrorMessage = "投稿できるのは最大\(maxTracks)曲までです"
            } else {
                publishErrorMessage = "無料版では最大\(maxTracks)曲まで投稿できます。プレミアムにアップグレードすると\(FreeTierLimits.maxTracksForPublishPremium)曲まで投稿可能です"
            }
            showingPublishError = true
            return
        }

        // 確認ダイアログを表示
        showingPublishConfirm = true
    }

    /// プレイリストを投稿
    private func publishPlaylist() {
        guard let userId = authManager.currentUser?.uid else { return }

        isPublishing = true

        Task {
            do {
                // ユーザープロフィールを取得
                let userProfile = try await communityManager.getUserProfile(userId: userId)

                // 投稿
                try await communityManager.publishPlaylist(
                    playlist: playlist,
                    authorId: userId,
                    authorName: userProfile.displayName,
                    authorIsPremium: storeManager.isPremium,
                    authorCountryCode: userProfile.countryCode,
                    authorArtworkURL: userProfile.profileArtworkURL
                )

                await MainActor.run {
                    isPublishing = false
                    showingPublishSuccess = true
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishErrorMessage = error.localizedDescription
                    showingPublishError = true
                }
            }
        }
    }

    private func handlePlayStop() {
        // プレビュー再生中なら停止
        if previewingTrackId != nil {
            stopPreview()
            return
        }

        if playerManager.isPlaying {
            playerManager.stop()
        } else {
            // クロージャで渡すことで、再生中のトラック順変更がリアルタイムで反映される
            playerManager.play { [playlist] in
                playlist.sortedTracks
            }
        }
    }

    private func handlePrevious() {
        if previewingTrackId != nil {
            // プレビュー再生中: 前のトラックに移動
            let sortedTracks = playlist.sortedTracks
            guard let currentIndex = sortedTracks.firstIndex(where: { $0.id == previewingTrackId }) else { return }
            let previousIndex = currentIndex - 1
            guard previousIndex >= 0 else { return }
            previewTrack(sortedTracks[previousIndex])
        } else {
            playerManager.previous()
        }
    }

    private func handleNext() {
        if previewingTrackId != nil {
            // プレビュー再生中: 次のトラックに移動
            let sortedTracks = playlist.sortedTracks
            guard let currentIndex = sortedTracks.firstIndex(where: { $0.id == previewingTrackId }) else { return }
            let nextIndex = currentIndex + 1
            guard nextIndex < sortedTracks.count else { return }
            previewTrack(sortedTracks[nextIndex])
        } else {
            playerManager.next()
        }
    }
    
    private func deleteTracks(at offsets: IndexSet) {
        let sortedTracks = playlist.sortedTracks
        for index in offsets {
            modelContext.delete(sortedTracks[index])
        }
    }
    
    private func moveTracks(from source: IndexSet, to destination: Int) {
        var tracks = playlist.sortedTracks
        tracks.move(fromOffsets: source, toOffset: destination)
        
        // orderIndexを更新
        for (index, track) in tracks.enumerated() {
            track.orderIndex = index
        }
    }
    
    private func loadFirstTrackArtwork() async {
        guard let firstTrack = playlist.sortedTracks.first else {
            backgroundArtworkURL = nil
            return
        }
        
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(firstTrack.appleMusicSongId)
            )
            let response = try await request.response()
            if let song = response.items.first, let artwork = song.artwork {
                backgroundArtworkURL = artwork.url(width: 400, height: 400)
            }
        } catch {
            print("Background artwork load error: \(error)")
        }
    }
    
}

// MARK: - TrackRow
struct TrackRow: View {
    let track: TrackInPlaylist
    var isPlaying: Bool = false
    var onArtworkTap: (() -> Void)?
    @State private var artworkURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            // アートワーク（タップでプレビュー再生）
            Group {
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
            }
            .onTapGesture {
                onArtworkTap?()
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
                Text("\(track.chorusStartFormatted) - \(track.chorusEndFormatted)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
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
        var song: Song?
        
        // まずIDで検索（エラーをキャッチして続行）
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(track.appleMusicSongId)
            )
            let response = try await request.response()
            song = response.items.first
        } catch {
            print("⚠️ ID search failed for artwork: \(error)")
        }
        
        // IDで見つからない場合はタイトルとアーティストで検索
        if song == nil {
            do {
                var searchRequest = MusicCatalogSearchRequest(term: "\(track.title) \(track.artist)", types: [Song.self])
                searchRequest.limit = 5
                let searchResponse = try await searchRequest.response()
                song = searchResponse.songs.first { $0.title == track.title && $0.artistName == track.artist }
                    ?? searchResponse.songs.first
            } catch {
                print("❌ Text search also failed for artwork: \(error)")
            }
        }
        
        if let foundSong = song, let artwork = foundSong.artwork {
            artworkURL = artwork.url(width: 100, height: 100)
        }
    }
}

// MARK: - SignInSheetView
struct SignInSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text(String(localized: "please_sign_in"))
                    .font(.headline)

                Text(String(localized: "sign_in_to_publish"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        let nonce = authManager.generateNonce()
                        request.requestedScopes = []
                        request.nonce = authManager.sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task {
                                try? await authManager.signInWithApple(authorization: authorization)
                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        case .failure(let error):
                            print("Sign in with Apple failed: \(error)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle(String(localized: "sign_in"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(playlist: Playlist(name: "テストプレイリスト"))
    }
    .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}
