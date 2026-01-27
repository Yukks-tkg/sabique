//
//  ChorusEditView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import MusicKit
import Combine

struct ChorusEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var track: TrackInPlaylist
    
    var onSave: (() -> Void)?
    
    @State private var chorusStart: Double?
    @State private var chorusEnd: Double?
    
    @State private var isPlaying = false
    @State private var playbackTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var artworkURL: URL?
    
    private let player = SystemMusicPlayer.shared
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var skipTimer: AnyCancellable?
    @State private var isPreviewing = false
    @State private var isDraggingSeekbar = false
    @State private var shakeTrigger = 0
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = true
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // ダイナミック背景: アートワークをぼかして配置
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
                            Color.black
                        }
                    } else {
                        Color.black
                    }
                    
                    // 背景のオーバーレイ（視認性を確保）
                    Color.black.opacity(0.25)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 80) // ナビゲーションバーの余白
                    // アートワーク
                    if let url = artworkURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 200, height: 200)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            )
                    }
                
                // 曲情報
                VStack(spacing: 4) {
                    Text(track.title)
                        .font(.title3)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                
                // 再生コントロール & シークバー
                VStack(spacing: 10) {
                    // 再生時間表示
                    HStack {
                        Text(formatTime(playbackTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    
                    // カスタムシークバー
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景トラック
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            // 再生済みトラック
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: CGFloat(playbackTime / max(duration, 1)) * geometry.size.width, height: 4)
                                .animation(.linear(duration: 0.1), value: playbackTime)
                            
                            // 開始キューポイント（青い縦線 + ドラッグ可能な丸）
                            if let start = chorusStart, duration > 0 {
                                let startX = CGFloat(start / duration) * geometry.size.width
                                // 縦線
                                Rectangle()
                                    .fill(track.isLocked ? .gray : .blue)
                                    .frame(width: 3, height: 40)
                                    .position(x: startX, y: 18)
                                
                                // 丸（ドラッグ判定あり）
                                ZStack {
                                    // 透明なタップ領域（大きめ）
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 44, height: 44)
                                    // 視覚的な丸
                                    Circle()
                                        .fill(track.isLocked ? .gray : .blue)
                                        .frame(width: 16, height: 16)
                                }
                                .contentShape(Circle().size(width: 44, height: 44))
                                .position(x: startX, y: 46)
                                .highPriorityGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            guard !track.isLocked else {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shakeTrigger += 1 }
                                                return
                                            }
                                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                            let newTime = progress * duration
                                            if let endTime = chorusEnd {
                                                chorusStart = min(newTime, endTime - 1)
                                            } else {
                                                chorusStart = newTime
                                            }
                                        }
                                        .onEnded { _ in
                                            guard !track.isLocked else { return }
                                            track.chorusStartSeconds = chorusStart
                                        }
                                )
                            }
                            
                            // 終了キューポイント（赤い縦線 + ドラッグ可能な丸）
                            if let end = chorusEnd, duration > 0 {
                                let endX = CGFloat(end / duration) * geometry.size.width
                                // 縦線
                                Rectangle()
                                    .fill(track.isLocked ? .gray : .red)
                                    .frame(width: 3, height: 40)
                                    .position(x: endX, y: 18)
                                
                                // 丸（ドラッグ判定あり）
                                ZStack {
                                    // 透明なタップ領域（大きめ）
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 44, height: 44)
                                    // 視覚的な丸
                                    Circle()
                                        .fill(track.isLocked ? .gray : .red)
                                        .frame(width: 16, height: 16)
                                }
                                .contentShape(Circle().size(width: 44, height: 44))
                                .position(x: endX, y: 46)
                                .highPriorityGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            guard !track.isLocked else {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shakeTrigger += 1 }
                                                return
                                            }
                                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                            let newTime = progress * duration
                                            if let startTime = chorusStart {
                                                chorusEnd = max(newTime, startTime + 1)
                                            } else {
                                                chorusEnd = newTime
                                            }
                                        }
                                        .onEnded { _ in
                                            guard !track.isLocked else { return }
                                            track.chorusEndSeconds = chorusEnd
                                        }
                                )
                            }
                            
                            // 高さを常に確保するための透明なプレースホルダー
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 1, height: 20)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    isDraggingSeekbar = true
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    playbackTime = progress * duration
                                }
                                .onEnded { _ in
                                    player.playbackTime = playbackTime
                                    isDraggingSeekbar = false
                                }
                        )
                    }
                    .frame(height: 36)
                    
                    Spacer().frame(height: 24)
                    
                    HStack(spacing: 28) {
                        // 曲の最初へ
                        Button(action: { goToStart() }) {
                            Image(systemName: "backward.end.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                        
                        // 開始キューポイントへジャンプ（青）
                        Button(action: {
                            if let start = chorusStart {
                                playbackTime = start
                                player.playbackTime = start
                            }
                        }) {
                            Image(systemName: "backward.frame.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(chorusStart == nil ? .blue.opacity(0.4) : .blue)
                        }
                        .disabled(chorusStart == nil)
                        .opacity(chorusStart == nil ? 0.6 : 1.0)
                        
                        // 巻き戻しボタン（-5秒）
                        Button(action: { skipBackward() }) {
                            Image(systemName: "gobackward.5")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .onEnded { _ in
                                    startContinuousSkip(forward: false)
                                }
                        )
                        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                            if !pressing {
                                stopContinuousSkip()
                            }
                        }, perform: {})
                        
                        // 再生/一時停止ボタン
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .resizable()
                                .frame(width: 44, height: 44)
                        }
                        
                        // 早送りボタン（+5秒）
                        Button(action: { skipForward() }) {
                            Image(systemName: "goforward.5")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .onEnded { _ in
                                    startContinuousSkip(forward: true)
                                }
                        )
                        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                            if !pressing {
                                stopContinuousSkip()
                            }
                        }, perform: {})
                        
                        // 終了キューポイントへジャンプ（赤）
                        Button(action: {
                            if let end = chorusEnd {
                                playbackTime = end
                                player.playbackTime = end
                            }
                        }) {
                            Image(systemName: "forward.frame.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(chorusEnd == nil ? .red.opacity(0.4) : .red)
                        }
                        .disabled(chorusEnd == nil)
                        .opacity(chorusEnd == nil ? 0.6 : 1.0)
                        
                        // 曲の最後へ
                        Button(action: { goToEnd() }) {
                            Image(systemName: "forward.end.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.vertical)
                }
                .padding(.horizontal)
                
                // ハイライト設定ボタン（コンパクトカードデザイン）
                HStack(spacing: 16) {
                    let isStartDisabled = chorusEnd != nil && playbackTime > chorusEnd!
                    let isEndDisabled = chorusStart != nil && playbackTime < chorusStart!
                    
                    // 開始ポイント設定カード
                    Button(action: {
                        if track.isLocked {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shakeTrigger += 1 }
                            return
                        }
                        chorusStart = playbackTime
                        track.chorusStartSeconds = playbackTime
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "start"))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(chorusStart.map { formatTime($0) } ?? "--:--")
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right.to.line")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(isStartDisabled)
                    .opacity((track.isLocked || isStartDisabled) ? 0.4 : 1.0)
                    
                    // 終了ポイント設定カード
                    Button(action: {
                        if track.isLocked {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shakeTrigger += 1 }
                            return
                        }
                        chorusEnd = playbackTime
                        track.chorusEndSeconds = playbackTime
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "end"))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(chorusEnd.map { formatTime($0) } ?? "--:--")
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.left.to.line")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(isEndDisabled)
                    .opacity((track.isLocked || isEndDisabled) ? 0.4 : 1.0)
                }
                .padding(.horizontal)
                
                // ハイライト再生ボタンとリセット・ロックボタン
                let canPreview = chorusStart != nil && chorusEnd != nil && (chorusEnd ?? 0) > (chorusStart ?? 0)
                HStack(spacing: 12) {
                    // リセットボタン
                    Button(action: {
                        chorusStart = nil
                        chorusEnd = nil
                        track.chorusStartSeconds = nil
                        track.chorusEndSeconds = nil
                        isPreviewing = false // ハイライト再生状態をリセット
                    }) {
                        Image(systemName: "eraser")
                            .font(.title2)
                            .foregroundColor(track.isLocked ? .gray : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .disabled(track.isLocked || (chorusStart == nil && chorusEnd == nil))
                    .opacity((track.isLocked || (chorusStart == nil && chorusEnd == nil)) ? 0.4 : 1.0)
                    
                    // ハイライト再生ボタン
                    Button(action: togglePreview) {
                        Label(isPreviewing ? String(localized: "highlight_stop") : String(localized: "highlight_play"), systemImage: isPreviewing ? "stop.fill" : "repeat")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                canPreview ?
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) : LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canPreview)
                    .opacity(canPreview ? 1.0 : 0.5)
                    
                    // ロックボタン（両方のキューポイントが設定されているときのみ有効）
                    let hasBothCuePoints = chorusStart != nil && chorusEnd != nil
                    Button(action: {
                        track.isLocked.toggle()
                    }) {
                        Image(systemName: track.isLocked ? "lock.fill" : "lock.open")
                            .font(.title2)
                            .modifier(Shake(animatableData: CGFloat(shakeTrigger)))
                            .foregroundColor(track.isLocked ? .orange : (hasBothCuePoints ? .white : .gray))
                            .frame(width: 44, height: 44)
                            .background(track.isLocked ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .disabled(!hasBothCuePoints)
                    .opacity(hasBothCuePoints ? 1.0 : 0.4)
                }
                .padding(.horizontal)
                .padding(.bottom, 20) // 下部の余白を詰める
                } // VStack
                } // ScrollView
            } // ZStack
            } // GeometryReader
            .ignoresSafeArea()
            .navigationTitle(String(localized: "highlight_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            .preferredColorScheme(.dark)
            .onAppear {
                setupPlayer()
                loadCurrentValues()
            }
            .onReceive(timer) { _ in
                updatePlaybackStatus()
            }
            .onDisappear {
                // プレビューモードのみ解除（通常再生は継続）
                isPreviewing = false
            }
        }
    }
    
    private func setupPlayer() {
        // 再生位置をリセット
        playbackTime = 0
        
        // 現在の再生を停止
        player.stop()
        
        Task {
            var song: Song?
            
            print("🎵 Searching for song ID: \(track.appleMusicSongId)")
            
            // まずIDで曲を検索（エラーをキャッチして続行）
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(track.appleMusicSongId))
                let response = try await request.response()
                song = response.items.first
                print("🎵 ID search result: \(song?.title ?? "not found")")
            } catch {
                print("⚠️ ID search failed (will try text search): \(error)")
            }
            
            // IDで見つからない場合はタイトルとアーティストで検索
            if song == nil {
                do {
                    let searchTerm = "\(track.title) \(track.artist)"
                    print("🎵 Searching with term: \(searchTerm)")
                    
                    var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
                    searchRequest.limit = 10
                    let searchResponse = try await searchRequest.response()
                    
                    print("🎵 Search results count: \(searchResponse.songs.count)")
                    
                    // 完全一致を優先
                    song = searchResponse.songs.first { $0.title == track.title && $0.artistName == track.artist }
                    
                    // 部分一致でフォールバック
                    if song == nil {
                        song = searchResponse.songs.first { $0.title.contains(track.title) || track.title.contains($0.title) }
                    }
                    
                    // それでも見つからなければ最初の結果を使用
                    if song == nil {
                        song = searchResponse.songs.first
                    }
                    
                    print("🎵 Final search result: \(song?.title ?? "still not found")")
                } catch {
                    print("❌ Text search also failed: \(error)")
                }
            }
            
            guard let foundSong = song else {
                print("❌ Song not found: \(track.title) by \(track.artist)")
                return
            }
            
            print("✅ Found song: \(foundSong.title) by \(foundSong.artistName)")
            
            // MainActorでUI関連の変数を更新
            await MainActor.run {
                // アートワークURLを取得
                if let artwork = foundSong.artwork {
                    artworkURL = artwork.url(width: 400, height: 400)
                    print("✅ Artwork URL set")
                }
                
                duration = foundSong.duration ?? 0
                print("✅ Duration: \(duration)")
            }
            
            // このトラックのキューを設定
            player.queue = [foundSong]
            
            // 再生位置を初期化（新規トラックは0、設定済みは開始2秒前）
            let startTime: TimeInterval
            if let start = track.chorusStartSeconds {
                startTime = max(0, start - 2)
            } else {
                startTime = 0
            }
            
            // 自動再生がオンの場合のみ再生開始
            if autoPlayOnOpen {
                do {
                    try await player.play()
                    // 再生開始後に時間を設定（再生開始前にセットすると0にリセットされる場合があるため）
                    player.playbackTime = startTime
                    print("✅ Playback started at: \(startTime)")
                } catch {
                    print("❌ Player play error: \(error)")
                }
            } else {
                // 自動再生オフの場合は、準備だけしておき、時間を設定
                player.playbackTime = startTime
            }
        }
    }
    
    private func loadCurrentValues() {
        chorusStart = track.chorusStartSeconds
        chorusEnd = track.chorusEndSeconds
    }
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            Task {
                try? await player.play()
            }
        }
    }
    
    private func stopPlayback() {
        player.stop()
        isPlaying = false
        skipTimer?.cancel()
        skipTimer = nil
    }
    
    private func skipForward() {
        let newTime = min(playbackTime + 5, duration)
        playbackTime = newTime
        player.playbackTime = newTime
    }
    
    private func skipBackward() {
        let newTime = max(playbackTime - 5, 0)
        playbackTime = newTime
        player.playbackTime = newTime
    }
    
    private func goToStart() {
        playbackTime = 0
        player.playbackTime = 0
    }
    
    private func goToEnd() {
        let endTime = max(duration - 1, 0)
        playbackTime = endTime
        player.playbackTime = endTime
    }
    
    private func startContinuousSkip(forward: Bool) {
        skipTimer?.cancel()
        skipTimer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if forward {
                    let newTime = min(self.playbackTime + 1, self.duration)
                    self.playbackTime = newTime
                    self.player.playbackTime = newTime
                } else {
                    let newTime = max(self.playbackTime - 1, 0)
                    self.playbackTime = newTime
                    self.player.playbackTime = newTime
                }
            }
    }
    
    private func stopContinuousSkip() {
        skipTimer?.cancel()
        skipTimer = nil
    }
    
    private func updatePlaybackStatus() {
        Task { @MainActor in
            // ドラッグ中はplaybackTimeを上書きしない
            if !isDraggingSeekbar {
                playbackTime = player.playbackTime
            }
            isPlaying = player.state.playbackStatus == .playing
            
            // ハイライトプレビュー中に終了点を過ぎたら開始点に戻る
            if isPreviewing,
               let start = chorusStart,
               let end = chorusEnd,
               playbackTime >= end {
                player.playbackTime = start
            }
        }
    }
    
    private func togglePreview() {
        if isPreviewing {
            // プレビュー停止
            isPreviewing = false
            player.pause()
        } else {
            // プレビュー開始
            guard let start = chorusStart else { return }
            isPreviewing = true
            Task {
                try? await player.play()
                player.playbackTime = start
            }
        }
    }
    
    private func previewChorus() {
        guard let start = chorusStart else { return }
        Task {
            try? await player.play()
            player.playbackTime = start
        }
    }
    
    private func saveAndDismiss() {
        // Defer state mutations and dismissal to avoid "Modifying state during view update"
        let start = chorusStart
        let end = chorusEnd
        DispatchQueue.main.async {
            self.track.chorusStartSeconds = start
            self.track.chorusEndSeconds = end
            self.stopPlayback()
            self.onSave?()
            self.dismiss()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    ChorusEditView(
        track: TrackInPlaylist(
            appleMusicSongId: "test",
            title: "テスト曲",
            artist: "テストアーティスト",
            orderIndex: 0
        )
    )
}

struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

