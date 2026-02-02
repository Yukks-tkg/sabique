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
    
    /// トラックリストを取得するクロージャ（常に最新の順序を返す）
    private var tracksProvider: (() -> [TrackInPlaylist])?
    private let player = ApplicationMusicPlayer.shared
    private var timerCancellable: AnyCancellable?
    private var currentPlayTask: Task<Void, Never>?
    private var isTransitioning = false
    
    /// 現在のトラックリスト（常に最新を取得）
    private var tracks: [TrackInPlaylist] {
        tracksProvider?() ?? []
    }
    
    init() {
        // タイマーで制御するため、playbackObserverは使用しない
    }
    
    /// ハイライト連続再生を開始
    func play(tracks: @escaping () -> [TrackInPlaylist]) {
        self.tracksProvider = tracks
        
        guard !self.tracks.isEmpty else {
            print("曲がありません")
            return
        }
        
        currentTrackIndex = 0
        isPlaying = true
        isTransitioning = false
        
        playCurrentTrack()
    }
    
    /// 再生を停止
    func stop() {
        isPlaying = false
        isTransitioning = false
        timerCancellable?.cancel()
        timerCancellable = nil
        currentPlayTask?.cancel()
        currentPlayTask = nil
        player.stop()
        currentTrack = nil
        tracksProvider = nil
        print("🛑 再生停止")
    }
    
    /// 次の曲へ
    func next() {
        guard !isTransitioning else { return }
        
        // 現在再生中のトラックのIDを使って、最新のリストでの次のトラックを見つける
        if let currentTrack = currentTrack,
           let currentIndex = tracks.firstIndex(where: { $0.id == currentTrack.id }) {
            currentTrackIndex = currentIndex + 1
        } else {
            currentTrackIndex += 1
        }
        
        if currentTrackIndex >= tracks.count {
            // 最後まで再生完了、最初に戻ってリピート
            currentTrackIndex = 0
            print("🔁 リピート: 最初の曲に戻ります")
        }
        
        playCurrentTrack()
    }
    
    /// 前の曲へ
    func previous() {
        guard !isTransitioning else { return }
        
        // 現在再生中のトラックのIDを使って、最新のリストでの前のトラックを見つける
        if let currentTrack = currentTrack,
           let currentIndex = tracks.firstIndex(where: { $0.id == currentTrack.id }) {
            currentTrackIndex = currentIndex - 1
        } else {
            currentTrackIndex -= 1
        }
        
        if currentTrackIndex < 0 {
            // 最初より前、最後の曲に移動
            currentTrackIndex = tracks.count - 1
            print("🔁 リピート: 最後の曲に移動します")
        }
        
        playCurrentTrack()
    }
    
    /// 現在の曲を再生
    private func playCurrentTrack() {
        let currentTracks = tracks
        guard currentTrackIndex < currentTracks.count else {
            stop()
            return
        }
        
        // 既存のタスクとタイマーをキャンセル
        currentPlayTask?.cancel()
        timerCancellable?.cancel()
        
        isTransitioning = true
        
        let track = currentTracks[currentTrackIndex]
        currentTrack = track
        
        currentPlayTask = Task {
            do {
                // Apple Music IDから曲を取得
                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(track.appleMusicSongId)
                )
                let response = try await request.response()
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }
                
                guard let song = response.items.first else {
                    print("曲が見つかりません: \(track.title)")
                    isTransitioning = false
                    next()
                    return
                }
                
                // 曲を再生
                player.queue = [song]
                try await player.play()
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }
                
                let startTime = track.chorusStartSeconds ?? 0
                let endTime = track.chorusEndSeconds ?? (song.duration ?? 0)
                
                // 開始位置へシーク
                player.playbackTime = startTime
                
                isTransitioning = false
                
                // 次の曲へのタイマーをセット
                scheduleNextTrack(endTime: endTime)
                
            } catch {
                guard !Task.isCancelled else { return }
                print("再生エラー: \(error)")
                isTransitioning = false
                next()
            }
        }
    }
    
    /// 指定秒数後に次の曲へ移行するタイマーをセット
    private func scheduleNextTrack(endTime: Double) {
        timerCancellable?.cancel()
        
        print("📍 タイマーセット: トラック \(currentTrackIndex + 1)/\(tracks.count), 終了時間: \(endTime)秒")
        
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying, !self.isTransitioning else { return }
                
                let currentTime = self.player.playbackTime
                
                // 終了時間を過ぎたら次の曲へ（リピート再生）
                if currentTime >= endTime {
                    print("⏰ 終了時間到達: \(currentTime) >= \(endTime)")
                    self.timerCancellable?.cancel()
                    self.next()
                }
            }
    }
}
