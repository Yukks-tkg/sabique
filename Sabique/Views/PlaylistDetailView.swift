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
    @State private var shouldScrollToCurrentTrack = false
    @State private var previousTrackCount = 0
    @State private var showingRenameAlert = false
    @State private var newPlaylistName = ""
    @State private var playbarEditTrack: TrackInPlaylist?
    @State private var playbarSeekTime: Double?


    // 投稿関連
    @State private var showingPublishConfirm = false
    @State private var showingSignInSheet = false
    @State private var showingPublishSuccess = false
    @State private var showingPublishError = false
    @State private var publishErrorMessage = ""
    @State private var isPublishing = false

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    @AppStorage("isLeftHandedMode") private var isLeftHandedMode: Bool = false
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.6
    @AppStorage("backgroundBlurRadius") private var backgroundBlurRadius: Double = 30

    /// アートワークのスライド方向（次へ: .trailing、前へ: .leading）
    @State private var slideDirection: Edge = .trailing

    // 1曲目のID（並べ替え検知用）
    private var firstTrackId: String? {
        playlist.sortedTracks.first?.appleMusicSongId
    }
    
    @EnvironmentObject private var playerManager: ChorusPlayerManager
    
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
                    // ハイライト再生中なら停止（SystemMusicPlayerとの競合防止）
                    if playerManager.isPlaying {
                        playerManager.stop()
                    }
                    // シート表示時のトラック数を記録
                    previousTrackCount = playlist.tracks.count
                }
        }
        .onAppear {
            // 既に再生中なら現在のトラックまでスクロール（ウィジェットからの遷移など）
            if playerManager.isPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shouldScrollToCurrentTrack = true
                }
            }
        }
        .onDisappear {
            // 画面を離れたら再生を停止
            if playerManager.isPlaying {
                playerManager.stop()
            }
        }
        .onChange(of: playlist.sortedTracks.map(\.id)) { _, _ in
            playerManager.refreshPlaybackOrder()
        }
        .sheet(item: $selectedTrack, onDismiss: {
            // ハイライト設定画面から戻ったら再生を停止
            SystemMusicPlayer.shared.stop()
        }) { track in
            ChorusEditView(track: track)
                .onAppear {
                    // ハイライト再生中なら停止（SystemMusicPlayerとの競合防止）
                    if playerManager.isPlaying {
                        playerManager.stop()
                    }
                }
        }
        .sheet(item: $playbarEditTrack, onDismiss: {
            SystemMusicPlayer.shared.stop()
            playbarSeekTime = nil
        }) { track in
            ChorusEditView(track: track, initialSeekTime: playbarSeekTime)
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
                        .blur(radius: backgroundBlurRadius)
                        .opacity(backgroundOpacity)
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
        ContentUnavailableView(
            String(localized: "no_songs"),
            systemImage: "music.note",
            description: Text(String(localized: "no_songs_description"))
        )
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
            .onChange(of: shouldScrollToCurrentTrack) { _, newValue in
                if newValue, let trackId = playerManager.currentTrack?.id {
                    withAnimation {
                        proxy.scrollTo(trackId, anchor: .center)
                    }
                    shouldScrollToCurrentTrack = false
                }
            }
            .onChange(of: playerManager.currentTrack?.id) { _, _ in
                // 再生トラックが変わったら自動スクロール
                if playerManager.isPlaying, let trackId = playerManager.currentTrack?.id {
                    withAnimation {
                        proxy.scrollTo(trackId, anchor: .center)
                    }
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
        return TrackRow(
            track: track,
            isPlaying: isCurrentlyPlaying,
            onPlay: { previewTrack(track) },
            onEdit: {
                if playerManager.isPlaying {
                    playerManager.stop()
                }
                selectedTrack = track
                showingChorusEdit = true
            }
        )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentlyPlaying ? Color.white.opacity(0.2) : Color.clear)
            )
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

    /// トラックタップでハイライト連続再生を開始（タップした曲から）
    private func previewTrack(_ track: TrackInPlaylist) {
        // 同じ曲をタップしたら停止
        if playerManager.isPlaying && playerManager.currentTrack?.id == track.id {
            playerManager.stop()
            return
        }

        // 再生中なら停止してから開始
        if playerManager.isPlaying {
            playerManager.stop()
        }

        // タップした曲からハイライト連続再生を開始
        playerManager.playFrom(track: track) { [playlist] in
            playlist.sortedTracks
        }
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

            Spacer(minLength: 8)
            Button {
                playerManager.setShuffleEnabled(!playerManager.isShuffleEnabled)
            } label: {
                Image(systemName: "shuffle")
                    .foregroundColor(playerManager.isShuffleEnabled ? .orange : .secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shufflePlaybackButton")
            .accessibilityLabel(String(localized: "shuffle_playback", table: "PlaybackControls"))
            .accessibilityValue(playerManager.isShuffleEnabled
                ? String(localized: "shuffle_on", table: "PlaybackControls")
                : String(localized: "shuffle_off", table: "PlaybackControls"))
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
            playbackCard
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

    private var playbackCard: some View {
        HStack(spacing: 12) {
            if isLeftHandedMode {
                // 左利きモード：コントロール → 曲情報 → アートワーク
                playbackControls
                currentTrackInfo
                Spacer()
                currentTrackArtwork
            } else {
                // 右利きモード（デフォルト）：アートワーク → 曲情報 → コントロール
                currentTrackArtwork
                currentTrackInfo
                Spacer()
                playbackControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.8))
    }

    @ViewBuilder
    private var currentTrackArtwork: some View {
        RotatingArtwork(
            artworkURL: playerManager.currentTrack?.artworkURL,
            isRotating: playerManager.isPlaying && !playerManager.isPaused,
            onHoldPause: { isHolding in
                handleArtworkHold(isHolding: isHolding)
            }
        )
        .id(playerManager.currentTrack?.id)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .animation(.easeOut(duration: 0.25), value: playerManager.currentTrack?.id)
    }

    private var placeholderArtwork: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.gray)
                    .font(.title3)
            )
    }

    private var currentTrackInfo: some View {
        VStack(alignment: isLeftHandedMode ? .trailing : .leading, spacing: 2) {
            if let currentTrack = playerManager.currentTrack {
                ViewThatFits(in: .horizontal) {
                    // まず通常サイズで1行に収まるか試す（タイトル15pt / アーティスト13pt）
                    VStack(alignment: isLeftHandedMode ? .trailing : .leading, spacing: 2) {
                        Text(currentTrack.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: true, vertical: false)
                            .lineLimit(1)

                        Text(currentTrack.artist)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    // 収まらなければ小さめフォントで2行表示（タイトル12pt / アーティスト10.5pt）
                    VStack(alignment: isLeftHandedMode ? .trailing : .leading, spacing: 2) {
                        Text(currentTrack.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(isLeftHandedMode ? .trailing : .leading)

                        Text(currentTrack.artist)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isLeftHandedMode ? .trailing : .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let track = playerManager.currentTrack else { return }
            // 現在の再生位置をキャプチャしてからChorusEditViewを開く
            let seekTime = playerManager.currentPlaybackTime
            playerManager.stop()
            playbarSeekTime = seekTime
            playbarEditTrack = track
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            // 前へボタン
            Button(action: { handlePrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }
            .disabled(!playerManager.isPlaying && !playerManager.isPaused)
            .opacity((playerManager.isPlaying || playerManager.isPaused) ? 1.0 : 0.4)

            // 再生/停止ボタン
            Button(action: handlePlayStop) {
                Image(systemName: (playerManager.isPlaying && !playerManager.isPaused) ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4), radius: 8, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)

            // 次へボタン
            Button(action: { handleNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }
            .disabled(!playerManager.isPlaying && !playerManager.isPaused)
            .opacity((playerManager.isPlaying || playerManager.isPaused) ? 1.0 : 0.4)
        }
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

                // デバッグログ
                print("🔍 PlaylistDetailView投稿時のプロフィール情報:")
                print("  - userId: \(userId)")
                print("  - nickname: \(userProfile.nickname ?? "nil")")
                print("  - displayName: \(userProfile.displayName ?? "nil")")

                // 投稿（nicknameを使用）
                try await communityManager.publishPlaylist(
                    playlist: playlist,
                    authorId: userId,
                    authorName: userProfile.nickname,
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
        if playerManager.isPlaying && !playerManager.isPaused {
            // 再生中 → 一時停止
            playerManager.pause()
        } else if playerManager.isPaused {
            // 一時停止中 → 再開
            playerManager.resume()
        } else {
            // 停止状態 → 先頭から再生
            playerManager.play { [playlist] in
                playlist.sortedTracks
            }
        }
    }

    private func handlePrevious() {
        slideDirection = .leading
        playerManager.previous()
    }

    private func handleNext() {
        slideDirection = .trailing
        playerManager.next()
    }

    /// アートワークのタップ&ホールド処理
    private func handleArtworkHold(isHolding: Bool) {
        if isHolding {
            // ホールド開始：再生中なら一時停止
            if playerManager.isPlaying {
                playerManager.pause()
            }
        } else {
            // ホールド解除：一時停止中なら再生再開
            if playerManager.isPaused {
                playerManager.resume()
            }
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

// MARK: - MarqueeText
/// 再生中の曲名を横スクロールするテキストコンポーネント
struct MarqueeText: View {
    let text: String
    let font: Font
    let isAnimating: Bool

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    /// アニメーションリセット用ID（変更するとView再生成で進行中アニメーションが破棄される）
    @State private var resetId = UUID()

    var body: some View {
        GeometryReader { geometry in
            let _ = updateContainerWidth(geometry.size.width)
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear {
                                textWidth = textGeometry.size.width
                            }
                    }
                )
                .offset(x: offset)
        }
        .clipped()
        .frame(height: UIFont.preferredFont(forTextStyle: .headline).lineHeight)
        .id(resetId)
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onChange(of: text) { _, _ in
            // テキストが変わったらリセット
            textWidth = 0
            offset = 0
            if isAnimating {
                startAnimation()
            }
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func updateContainerWidth(_ width: CGFloat) {
        if containerWidth != width {
            DispatchQueue.main.async {
                containerWidth = width
            }
        }
    }

    private func startAnimation() {
        stopAnimation()

        animationTask = Task { @MainActor in
            // テキスト幅の計測を待つ
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            guard textWidth > containerWidth else { return }

            while !Task.isCancelled {
                // 開始位置で少し待機
                offset = 0
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }

                // 左にスクロール
                let scrollDistance = textWidth - containerWidth + 20
                let duration = Double(scrollDistance) / 30.0 // 30pt/秒

                withAnimation(.linear(duration: duration)) {
                    offset = -scrollDistance
                }

                // スクロール完了を待機
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }

                // 端で少し待機
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }

                // 元に戻す（アニメーションなし）
                withAnimation(nil) {
                    offset = 0
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        // IDを変更してViewを再生成し、進行中のアニメーションを確実に破棄
        offset = 0
        resetId = UUID()
    }
}

// MARK: - TrackRow
struct TrackRow: View {
    let track: TrackInPlaylist
    var isPlaying: Bool = false
    var onPlay: (() -> Void)?
    var onEdit: (() -> Void)?
    @State private var artworkURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            // 再生エリア（アートワーク + 曲名）タップで再生
            Button(action: { onPlay?() }) {
                HStack(spacing: 12) {
                    // アートワーク
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

                    VStack(alignment: .leading, spacing: 4) {
                        MarqueeText(
                            text: track.title,
                            font: .headline,
                            isAnimating: isPlaying
                        )

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // 編集エリア（時間 or バッジ + chevron）タップでハイライト設定画面
            Button(action: { onEdit?() }) {
                HStack(spacing: 6) {
                    if track.hasChorusSettings {
                        Text("\(track.chorusStartFormatted) - \(track.chorusEndFormatted)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    } else {
                        Text(String(localized: "set_highlight"))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
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
            let url = artwork.url(width: 100, height: 100)
            artworkURL = url
            // SwiftDataにもキャッシュ（再生時のAPI呼び出しを省略できる）
            if track.artworkURL == nil {
                track.artworkURL = url
            }
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

// MARK: - RotatingArtwork
/// レコード風に回転するアートワーク
struct RotatingArtwork: View {
    let artworkURL: URL?
    let isRotating: Bool
    let onHoldPause: ((Bool) -> Void)?

    @State private var rotation: Double = 0
    @State private var isPressed: Bool = false

    var body: some View {
        ZStack {
            // 外側のレコード風の枠
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 54, height: 54)

            // アートワーク
            Group {
                if let url = artworkURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderContent
                    }
                } else {
                    placeholderContent
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // Viewが生成されたとき、回転中ならトランジション完了後に開始
                if isRotating {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        startRotation()
                    }
                }
            }
            .onChange(of: isRotating) { _, newValue in
                if newValue {
                    startRotation()
                } else {
                    stopRotation()
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onHoldPause?(true)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onHoldPause?(false)
                }
        )
    }

    private var placeholderContent: some View {
        ZStack {
            // 背景
            Circle()
                .fill(Color.gray.opacity(0.3))

            // Sabiqueロゴ
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .opacity(0.8)
        }
    }

    private func startRotation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func stopRotation() {
        withAnimation(.easeOut(duration: 0.5)) {
            rotation = 0
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(playlist: Playlist(name: "テストプレイリスト"))
    }
    .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
}

