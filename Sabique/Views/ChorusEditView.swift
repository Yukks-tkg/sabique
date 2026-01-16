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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
                    // カスタムシークバー + ピン
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景トラック
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            // 再生済みトラック
                            Capsule()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: CGFloat(playbackTime / max(duration, 1)) * geometry.size.width, height: 4)
                            
                            // サビ範囲のハイライト（再生済みトラックの上に表示）
                            if let start = chorusStart, let end = chorusEnd, end > start, duration > 0 {
                                let startX = CGFloat(start / duration) * geometry.size.width
                                let endX = CGFloat(end / duration) * geometry.size.width
                                let width = endX - startX
                                Rectangle()
                                    .fill(Color.green.opacity(0.5))
                                    .frame(width: width, height: 8)
                                    .cornerRadius(4)
                                    .position(x: startX + width / 2, y: geometry.size.height / 2)
                            }
                            
                            // 開始位置ピン（青）
                            if let start = chorusStart, duration > 0 {
                                let pinX = CGFloat(start / duration) * geometry.size.width
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: 2, height: 12)
                                }
                                .position(x: pinX, y: geometry.size.height / 2 - 4)
                            }
                            
                            // 終了位置ピン（赤）
                            if let end = chorusEnd, duration > 0 {
                                let pinX = CGFloat(end / duration) * geometry.size.width
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: 2, height: 12)
                                }
                                .position(x: pinX, y: geometry.size.height / 2 - 4)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    playbackTime = progress * duration
                                }
                                .onEnded { _ in
                                    player.playbackTime = playbackTime
                                }
                        )
                    }
                    .frame(height: 28)
                    
                    HStack {
                        Text(formatTime(playbackTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal)
                
                // サビ設定ボタン
                HStack(spacing: 20) {
                    VStack {
                        Button(action: {
                            chorusStart = playbackTime
                            // 開始位置が終了位置より後ろになった場合、終了位置をクリア
                            if let end = chorusEnd, playbackTime >= end {
                                chorusEnd = nil
                            }
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
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        HStack(spacing: 8) {
                            Text(chorusStart.map { formatTime($0) } ?? "--:--")
                                .font(.headline)
                                .monospacedDigit()
                            
                            if chorusStart != nil {
                                Button(action: {
                                    chorusStart = nil
                                    chorusEnd = nil  // 開始をリセットすると終了もリセット
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    
                    VStack {
                        Button(action: {
                            // 開始位置が設定されていて、現在位置が開始位置より後ろの場合のみ設定可能
                            if let start = chorusStart, playbackTime > start {
                                chorusEnd = playbackTime
                            } else if chorusStart == nil {
                                // 開始位置が未設定の場合はまず開始位置を設定するよう促す（何もしない）
                            }
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
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        // 終了ボタンは開始位置より後ろでないと押せないことを示す
                        .opacity(chorusStart == nil || playbackTime <= (chorusStart ?? 0) ? 0.5 : 1.0)
                        .disabled(chorusStart == nil || playbackTime <= (chorusStart ?? 0))
                        
                        HStack(spacing: 8) {
                            Text(chorusEnd.map { formatTime($0) } ?? "--:--")
                                .font(.headline)
                                .monospacedDigit()
                            
                            if chorusEnd != nil {
                                Button(action: { chorusEnd = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // プレビューボタン
                if let start = chorusStart, let end = chorusEnd, end > start {
                    Button(action: previewChorus) {
                        Label("サビのみ再生", systemImage: "waveform.path")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("サビを設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        stopPlayback()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAndDismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                setupPlayer()
                loadCurrentValues()
            }
            .onReceive(timer) { _ in
                updatePlaybackStatus()
            }
            .onDisappear {
                stopPlayback()
            }
        }
    }
    
    private func setupPlayer() {
        Task {
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(track.appleMusicSongId))
                let response = try await request.response()
                guard let song = response.items.first else { return }
                
                player.queue = [song]
                duration = song.duration ?? 0
                
                // アートワークURLを取得
                if let artwork = song.artwork {
                    artworkURL = artwork.url(width: 400, height: 400)
                }
                
                // 既に設定されている場合はその付近から再生開始
                if let start = track.chorusStartSeconds {
                    player.playbackTime = max(0, start - 2)
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
    }
    
    private func updatePlaybackStatus() {
        Task { @MainActor in
            playbackTime = player.playbackTime
            isPlaying = player.state.playbackStatus == .playing
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
