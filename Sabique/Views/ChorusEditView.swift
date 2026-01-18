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
                            Spacer().frame(height: 60) // ナビゲーションバーの余白
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
                                    .fill(Color.blue)
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
                                        .fill(Color.blue)
                                        .frame(width: 16, height: 16)
                                }
                                .contentShape(Circle().size(width: 44, height: 44))
                                .position(x: startX, y: 46)
                                .highPriorityGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                            let newTime = progress * duration
                                            if let endTime = chorusEnd {
                                                chorusStart = min(newTime, endTime - 1)
                                            } else {
                                                chorusStart = newTime
                                            }
                                        }
                                        .onEnded { _ in
                                            track.chorusStartSeconds = chorusStart
                                        }
                                )
                            }
                            
                            // 終了キューポイント（赤い縦線 + ドラッグ可能な丸）
                            if let end = chorusEnd, duration > 0 {
                                let endX = CGFloat(end / duration) * geometry.size.width
                                // 縦線
                                Rectangle()
                                    .fill(Color.red)
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
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                }
                                .contentShape(Circle().size(width: 44, height: 44))
                                .position(x: endX, y: 46)
                                .highPriorityGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                            let newTime = progress * duration
                                            if let startTime = chorusStart {
                                                chorusEnd = max(newTime, startTime + 1)
                                            } else {
                                                chorusEnd = newTime
                                            }
                                        }
                                        .onEnded { _ in
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
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    playbackTime = progress * duration
                                }
                                .onEnded { _ in
                                    player.playbackTime = playbackTime
                                }
                        )
                    }
                    .frame(height: 36)
                    
                    Spacer().frame(height: 24)
                    
                    HStack(spacing: 36) {
                        // 曲の最初へ
                        Button(action: { goToStart() }) {
                            Image(systemName: "backward.end.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                        
                        // 巻き戻しボタン（-5秒）
                        Button(action: { skipBackward() }) {
                            Image(systemName: "gobackward.5")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
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
                                .frame(width: 54, height: 54)
                        }
                        
                        // 早送りボタン（+5秒）
                        Button(action: { skipForward() }) {
                            Image(systemName: "goforward.5")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
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
                        
                        // 曲の最後へ
                        Button(action: { goToEnd() }) {
                            Image(systemName: "forward.end.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.vertical)
                }
                .padding(.horizontal)
                
                // ハイライト設定ボタン
                HStack(spacing: 20) {
                    let isStartDisabled = chorusEnd != nil && playbackTime > chorusEnd!
                    let isEndDisabled = chorusStart != nil && playbackTime < chorusStart!
                    
                    VStack {
                        Button(action: {
                            chorusStart = playbackTime
                            track.chorusStartSeconds = playbackTime
                        }) {
                            VStack {
                                Image(systemName: "arrow.right.to.line")
                                    .font(.title)
                                Text("ここを開始")
                                    .font(.caption)
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isStartDisabled ? Color.gray.opacity(0.3) : Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(isStartDisabled)
                        .opacity(isStartDisabled ? 0.5 : 1.0)
                        
                        Text(chorusStart.map { formatTime($0) } ?? "--:--")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    
                    VStack {
                        Button(action: {
                            chorusEnd = playbackTime
                            track.chorusEndSeconds = playbackTime
                        }) {
                            VStack {
                                Image(systemName: "arrow.left.to.line")
                                    .font(.title)
                                Text("ここを終了")
                                    .font(.caption)
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isEndDisabled ? Color.gray.opacity(0.3) : Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(isEndDisabled)
                        .opacity(isEndDisabled ? 0.5 : 1.0)
                        
                        Text(chorusEnd.map { formatTime($0) } ?? "--:--")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal)
                
                // プレビューボタン
                if let start = chorusStart, let end = chorusEnd, end > start {
                    Button(action: togglePreview) {
                        Label(isPreviewing ? "ハイライト停止" : "ハイライト再生", systemImage: isPreviewing ? "stop.fill" : "repeat")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isPreviewing ? Color.orange : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                } // VStack
                } // ScrollView
            } // ZStack
            } // GeometryReader
            .ignoresSafeArea()
            .navigationTitle("ハイライトを設定")
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
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(track.appleMusicSongId))
                let response = try await request.response()
                guard let song = response.items.first else { return }
                
                // アートワークURLを取得
                if let artwork = song.artwork {
                    artworkURL = artwork.url(width: 400, height: 400)
                }
                
                duration = song.duration ?? 0
                
                // このトラックのキューを設定して再生開始
                player.queue = [song]
                try await player.play()
                
                // 再生開始後にハイライト位置へシーク
                if let start = track.chorusStartSeconds {
                    player.playbackTime = max(0, start - 2)
                    playbackTime = player.playbackTime
                } else {
                    player.playbackTime = 0
                    playbackTime = 0
                }
            } catch {
                print("Player setup error: \(error)")
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
            playbackTime = player.playbackTime
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
