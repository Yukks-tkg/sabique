//
//  ChorusPlayerManager.swift
//  Sabique
//
//  Created by Sabiq App
//

import Foundation
import MusicKit
import Combine
import AVFoundation

@MainActor
class ChorusPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrackIndex = 0
    @Published var currentTrack: TrackInPlaylist?

    /// トラックリストを取得するクロージャ（常に最新の順序を返す）
    private var tracksProvider: (() -> [TrackInPlaylist])?
    private let player = ApplicationMusicPlayer.shared
    private var backgroundTimer: DispatchSourceTimer?
    private var currentPlayTask: Task<Void, Never>?
    private var isTransitioning = false

    /// 現在のトラックリスト（常に最新を取得）
    private var tracks: [TrackInPlaylist] {
        tracksProvider?() ?? []
    }

    init() {
        // タイマーで制御するため、playbackObserverは使用しない
    }

    /// AVAudioSessionを設定（バックグラウンド再生に必要）
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            print("🔊 AVAudioSession設定完了")
        } catch {
            print("⚠️ AVAudioSession設定エラー: \(error)")
        }
    }

    /// ハイライト連続再生を開始（先頭から）
    func play(tracks: @escaping () -> [TrackInPlaylist]) {
        playFrom(index: 0, tracks: tracks)
    }

    /// ハイライト連続再生を指定トラックから開始
    func playFrom(track: TrackInPlaylist, tracks: @escaping () -> [TrackInPlaylist]) {
        let currentTracks = tracks()
        let index = currentTracks.firstIndex(where: { $0.id == track.id }) ?? 0
        playFrom(index: index, tracks: tracks)
    }

    /// ハイライト連続再生を指定インデックスから開始
    private func playFrom(index: Int, tracks: @escaping () -> [TrackInPlaylist]) {
        self.tracksProvider = tracks

        guard !self.tracks.isEmpty else {
            print("曲がありません")
            return
        }

        // ApplicationMusicPlayer用にAudioSessionを設定
        configureAudioSession()

        // SystemMusicPlayerが再生中の場合は停止する
        SystemMusicPlayer.shared.stop()

        currentTrackIndex = min(index, self.tracks.count - 1)
        isPlaying = true
        isTransitioning = false

        playCurrentTrack()
    }

    /// 再生を停止
    func stop() {
        isPlaying = false
        isTransitioning = false
        cancelBackgroundTimer()
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
        cancelBackgroundTimer()

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

                // アートワークURLを更新（プレイヤーカード表示用）
                if let artwork = song.artwork {
                    track.artworkURL = artwork.url(width: 100, height: 100)
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

    /// 指定秒数後に次の曲へ移行するタイマーをセット（バックグラウンド対応）
    private func scheduleNextTrack(endTime: Double) {
        cancelBackgroundTimer()

        print("📍 タイマーセット: トラック \(currentTrackIndex + 1)/\(tracks.count), 終了時間: \(endTime)秒")

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))

        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying, !self.isTransitioning else { return }

                let currentTime = self.player.playbackTime

                // 終了時間を過ぎたら次の曲へ（リピート再生）
                if currentTime >= endTime {
                    print("⏰ 終了時間到達: \(currentTime) >= \(endTime)")
                    self.cancelBackgroundTimer()
                    self.next()
                }
            }
        }

        timer.resume()
        backgroundTimer = timer
    }

    /// バックグラウンドタイマーをキャンセル
    private func cancelBackgroundTimer() {
        backgroundTimer?.cancel()
        backgroundTimer = nil
    }
}
