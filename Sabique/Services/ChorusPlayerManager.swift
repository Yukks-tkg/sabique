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
import WidgetKit

@MainActor
class ChorusPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTrackIndex = 0
    @Published var currentTrack: TrackInPlaylist?

    /// トラックリストを取得するクロージャ（常に最新の順序を返す）
    private var tracksProvider: (() -> [TrackInPlaylist])?
    private let player = ApplicationMusicPlayer.shared
    private var backgroundTimer: DispatchSourceTimer?
    private var currentPlayTask: Task<Void, Never>?
    private var isTransitioning = false

    /// MusicKit Songオブジェクトのキャッシュ（Apple Music ID → Song）
    private var songCache: [String: Song] = [:]

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
        isPaused = false
        isTransitioning = false
        cancelBackgroundTimer()
        currentPlayTask?.cancel()
        currentPlayTask = nil
        player.stop()
        currentTrack = nil
        tracksProvider = nil
        print("🛑 再生停止")
    }

    /// 一時停止（ホールド時）
    func pause() {
        guard isPlaying && !isPaused else { return }
        isPaused = true
        player.pause()
        cancelBackgroundTimer()
        print("⏸️ 一時停止")
    }

    /// 再生再開（ホールド解除時）
    func resume() {
        guard isPaused else { return }
        isPaused = false

        Task {
            do {
                try await player.play()

                // タイマーを再開（現在の曲の残り時間で）
                if let track = currentTrack {
                    let endTime = track.chorusEndSeconds ?? 0
                    scheduleNextTrack(endTime: endTime)
                }

                print("▶️ 再生再開")
            } catch {
                print("再生再開エラー: \(error)")
            }
        }
    }

    /// 次の曲へ
    func next() {
        guard !isTransitioning else { return }
        isPaused = false

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
        isPaused = false

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

        // artworkURLがすでにキャッシュ済みなら即座にUI更新（トランジション即発火）
        if track.artworkURL != nil {
            currentTrack = track
        }

        currentPlayTask = Task {
            do {
                // キャッシュからSongを取得、なければAPIリクエスト
                let song: Song
                if let cached = songCache[track.appleMusicSongId] {
                    song = cached
                } else {
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: MusicItemID(track.appleMusicSongId)
                    )
                    let response = try await request.response()

                    guard !Task.isCancelled else { return }

                    guard let fetchedSong = response.items.first else {
                        print("曲が見つかりません: \(track.title)")
                        isTransitioning = false
                        next()
                        return
                    }
                    song = fetchedSong
                    songCache[track.appleMusicSongId] = song
                }

                // アートワークURLを更新（プレイヤーカード表示用）
                if let artwork = song.artwork {
                    track.artworkURL = artwork.url(width: 300, height: 300)
                }

                // artworkURLが未キャッシュだった場合はここでUI更新
                if currentTrack?.id != track.id {
                    currentTrack = track
                }

                // ウィジェット用にデータを保存
                saveNowPlayingForWidget(track: track)

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

                // 前後トラックのアートワークを先読み
                prefetchAllArtworks()

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

    /// 全トラックのアートワークURLと画像、Songオブジェクトを先読み
    private func prefetchAllArtworks() {
        let currentTracks = tracks
        guard !currentTracks.isEmpty else { return }

        Task {
            for track in currentTracks {
                guard !Task.isCancelled else { return }

                // Songがキャッシュ済みかつartworkURLもあれば画像だけ先読み
                if songCache[track.appleMusicSongId] != nil, let existingURL = track.artworkURL {
                    await prefetchImage(url: existingURL)
                    continue
                }

                // MusicKitからSongを取得してキャッシュ
                do {
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: MusicItemID(track.appleMusicSongId)
                    )
                    let response = try await request.response()
                    guard !Task.isCancelled else { return }

                    if let song = response.items.first {
                        songCache[track.appleMusicSongId] = song
                        if let artwork = song.artwork {
                            let url = artwork.url(width: 100, height: 100)
                            track.artworkURL = url
                            if let url {
                                await prefetchImage(url: url)
                            }
                        }
                    }
                } catch {
                    print("先読みエラー: \(track.title) - \(error)")
                }
            }
        }
    }

    /// URLの画像データをキャッシュに先読み
    private func prefetchImage(url: URL) async {
        do {
            let (_, _) = try await URLSession.shared.data(from: url)
        } catch {
            // 先読み失敗は無視
        }
    }

    /// バックグラウンドタイマーをキャンセル
    private func cancelBackgroundTimer() {
        backgroundTimer?.cancel()
        backgroundTimer = nil
    }

    /// 再生中の曲情報をウィジェット用に保存
    private func saveNowPlayingForWidget(track: TrackInPlaylist) {
        let defaults = UserDefaults(suiteName: "group.com.yuki.Sabique")
        defaults?.set(track.title, forKey: "nowPlaying.trackTitle")
        defaults?.set(track.artist, forKey: "nowPlaying.artistName")
        defaults?.set(track.playlist?.name ?? "", forKey: "nowPlaying.playlistName")
        defaults?.set(track.playlist?.id.uuidString ?? "", forKey: "nowPlaying.playlistId")

        // アートワークを画像データとして保存
        if let url = track.artworkURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    defaults?.set(data, forKey: "nowPlaying.artworkData")
                    WidgetCenter.shared.reloadTimelines(ofKind: "SabiqueWidget")
                }
            }
        } else {
            WidgetCenter.shared.reloadTimelines(ofKind: "SabiqueWidget")
        }
    }
}
