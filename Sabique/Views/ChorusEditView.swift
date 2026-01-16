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
                    // カスタムシークバー（小さい丸のサム）
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景トラック
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            // 再生済みトラック
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: CGFloat(playbackTime / max(duration, 1)) * geometry.size.width, height: 4)
                            
                            // サム（小さい丸）
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .shadow(radius: 2)
                                .offset(x: CGFloat(playbackTime / max(duration, 1)) * (geometry.size.width - 10))
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
                    }
                    .frame(height: 20)
                    
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
                        Button(action: { chorusStart = playbackTime }) {
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
                        
                        Text(chorusStart.map { formatTime($0) } ?? "--:--")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    
                    VStack {
                        Button(action: { chorusEnd = playbackTime }) {
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
                        
                        Text(chorusEnd.map { formatTime($0) } ?? "--:--")
                            .font(.headline)
                            .monospacedDigit()
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
