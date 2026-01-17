//
//  ChorusPlayerManager.swift
//  Sabique
//
//  Created by Sabiq App
//

import Foundation
import MusicKit
import Combine

@MainActor
class ChorusPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrackIndex = 0
    @Published var currentTrack: TrackInPlaylist?
    
    private var tracks: [TrackInPlaylist] = []
    private let player = ApplicationMusicPlayer.shared
    private var timerCancellable: AnyCancellable?
    
    init() {
        // タイマーで制御するため、playbackObserverは使用しない
    }
    
    /// ハイライト連続再生を開始
    func play(tracks: [TrackInPlaylist]) {
        self.tracks = tracks
        
        guard !self.tracks.isEmpty else {
            print("曲がありません")
            return
        }
        
        currentTrackIndex = 0
        isPlaying = true
        
        playCurrentTrack()
    }
    
    /// 再生を停止
    func stop() {
        isPlaying = false
        timerCancellable?.cancel()
        timerCancellable = nil
        player.stop()
        currentTrack = nil
        print("🛑 再生停止")
    }
    
    /// 次の曲へ
    func next() {
        currentTrackIndex += 1
        
        if currentTrackIndex >= tracks.count {
            // 最後まで再生完了
            stop()
            return
        }
        
        playCurrentTrack()
    }
    
    /// 現在の曲を再生
    private func playCurrentTrack() {
        guard currentTrackIndex < tracks.count else {
            stop()
            return
        }
        
        let track = tracks[currentTrackIndex]
        currentTrack = track
        
        Task {
            do {
                // Apple Music IDから曲を取得
                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(track.appleMusicSongId)
                )
                let response = try await request.response()
                
                guard let song = response.items.first else {
                    print("曲が見つかりません: \(track.title)")
                    next()
                    return
                }
                
                // 曲を再生
                player.queue = [song]
                try await player.play()
                
                let startTime = track.chorusStartSeconds ?? 0
                let endTime = track.chorusEndSeconds ?? (song.duration ?? 0)
                
                // 開始位置へシーク
                player.playbackTime = startTime
                
                // 次の曲へのタイマーをセット
                scheduleNextTrack(endTime: endTime)
                
            } catch {
                print("再生エラー: \(error)")
                next()
            }
        }
    }
    
    /// 指定秒数後に次の曲へ移行するタイマーをセット
    private func scheduleNextTrack(endTime: Double) {
        timerCancellable?.cancel()
        
        let isLastTrack = currentTrackIndex >= tracks.count - 1
        print("📍 タイマーセット: トラック \(currentTrackIndex + 1)/\(tracks.count), 終了時間: \(endTime)秒, 最後のトラック: \(isLastTrack)")
        
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                
                let currentTime = self.player.playbackTime
                
                // 終了時間を過ぎたら
                if currentTime >= endTime {
                    print("⏰ 終了時間到達: \(currentTime) >= \(endTime)")
                    self.timerCancellable?.cancel()
                    
                    if isLastTrack {
                        // 最後の曲の場合は停止
                        print("🏁 最後のトラック - 停止します")
                        self.stop()
                    } else {
                        // 次の曲へ
                        self.next()
                    }
                }
            }
    }
}
