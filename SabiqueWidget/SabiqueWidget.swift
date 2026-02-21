//
//  SabiqueWidget.swift
//  SabiqueWidget
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - データモデル

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let trackTitle: String
    let artistName: String
    let playlistName: String
    let playlistId: String
    let artworkData: Data?
    // 次の曲情報
    let nextTrackTitle: String
    let nextArtistName: String
    let nextArtworkData: Data?
}

// MARK: - Provider

struct NowPlayingProvider: TimelineProvider {

    private let suiteName = "group.com.yuki.Sabique"

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(
            date: .now,
            trackTitle: "どんなときも。",
            artistName: "槇原敬之",
            playlistName: "My Playlist",
            playlistId: "",
            artworkData: nil,
            nextTrackTitle: "Tomorrow never knows",
            nextArtistName: "Mr.Children",
            nextArtworkData: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = loadEntry()
        // 30分後に再取得
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> NowPlayingEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        let title = defaults?.string(forKey: "nowPlaying.trackTitle") ?? "曲が選択されていません"
        let artist = defaults?.string(forKey: "nowPlaying.artistName") ?? ""
        let playlist = defaults?.string(forKey: "nowPlaying.playlistName") ?? "Sabique"
        let playlistId = defaults?.string(forKey: "nowPlaying.playlistId") ?? ""
        let artworkData = defaults?.data(forKey: "nowPlaying.artworkData")
        let nextTitle = defaults?.string(forKey: "nowPlaying.nextTrackTitle") ?? ""
        let nextArtist = defaults?.string(forKey: "nowPlaying.nextArtistName") ?? ""
        let nextArtworkData = defaults?.data(forKey: "nowPlaying.nextArtworkData")

        return NowPlayingEntry(
            date: .now,
            trackTitle: title,
            artistName: artist,
            playlistName: playlist,
            playlistId: playlistId,
            artworkData: artworkData,
            nextTrackTitle: nextTitle,
            nextArtistName: nextArtist,
            nextArtworkData: nextArtworkData
        )
    }
}

// MARK: - Widget View

struct SabiqueWidgetEntryView: View {
    var entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: Small (正方形)
    private var smallView: some View {
        ZStack {
            VStack(spacing: 6) {
                // レコード盤
                recordDisk(size: 120)

                // プレイリスト名
                Text(entry.playlistName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: Medium (横長)
    private var mediumView: some View {
        ZStack {
            HStack(spacing: 0) {
                // レコード盤
                recordDisk(size: 145)

                // 曲情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.trackTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(entry.artistName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    Text(entry.playlistName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .padding(.top, 12)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: Large (縦長)
    private var largeView: some View {
        VStack(spacing: 0) {
            // 2枚のレコードを横に並べる
            HStack(alignment: .top, spacing: 16) {
                // 左: 現在の曲
                VStack(spacing: 10) {
                    Text("NOW PLAYING")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.2)

                    recordDisk(size: 130)

                    VStack(spacing: 3) {
                        Text(entry.trackTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)

                        Text(entry.artistName)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }

                // 右: 次の曲（少し薄く）
                VStack(spacing: 10) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.2)

                    recordDisk(size: 130, dimmed: true, useNextArtwork: true)

                    VStack(spacing: 3) {
                        Text(entry.nextTrackTitle.isEmpty ? "---" : entry.nextTrackTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)

                        Text(entry.nextArtistName.isEmpty ? "" : entry.nextArtistName)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.35))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // 再生ボタン
            Button(intent: PlayCurrentTrackIntent()) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("ハイライト再生")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // 下部: プレイリスト名
            Text(entry.playlistName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
            .padding(.bottom, 16)
        }
    }

    // MARK: レコード盤コンポーネント
    private func recordDisk(size: CGFloat, dimmed: Bool = false, useNextArtwork: Bool = false) -> some View {
        let grooveCount = 14
        let artworkData = useNextArtwork ? entry.nextArtworkData : entry.artworkData

        return ZStack {
            // 一番外側: レコードの本体（放射状グラデーションで質感を表現）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.18), // 内周（ラベル手前）: 少し明るめ
                            Color(white: 0.13), // 中間
                            Color(white: 0.10), // 外周に向かって少し暗く
                            Color(white: 0.08)  // 外周端: 締まった印象
                        ],
                        center: .center,
                        startRadius: size * 0.25,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)

            // レコードの溝（同心円）- 外周から内周（ラベル手前）まで密に配置
            ForEach(0..<grooveCount, id: \.self) { i in
                let ratio = 0.98 - Double(i) * 0.033
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.4)
                    .frame(width: size * ratio, height: size * ratio)
            }

            // アートワーク周りの黒リング
            let ringSize = size * 0.58
            Circle()
                .fill(Color(white: 0.06))
                .frame(width: ringSize, height: ringSize)

            // アートワーク（中央の丸いラベル部分）
            let labelSize = size * 0.52
            Group {
                if let data = artworkData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    recordLabelPlaceholder(size: labelSize)
                }
            }
            .frame(width: labelSize, height: labelSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )


            // 光沢オーバーレイ（左上からの光）
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04),
                            Color.clear,
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // 外枠のハイライト（強化）
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size, height: size)
            // 次の曲は暗くして「待機中」感を出す
            if dimmed {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: size, height: size)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 12, x: 4, y: 6)
    }

    private func recordLabelPlaceholder(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.2), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.3))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

// MARK: - Widget 定義

struct SabiqueWidget: Widget {
    let kind: String = "SabiqueWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            SabiqueWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if let data = entry.artworkData, let uiImage = UIImage(data: data) {
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 30)
                                .scaleEffect(1.3)
                            Color.black.opacity(0.25)
                        }
                    } else {
                        Color.black
                    }
                }
                .widgetURL(URL(string: "sabique://playlist?id=\(entry.playlistId)"))
        }
        .configurationDisplayName("Sabique")
        .description("最後に再生した曲をレコード風に表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SabiqueWidget()
} timeline: {
    NowPlayingEntry(
        date: .now,
        trackTitle: "どんなときも。",
        artistName: "槇原敬之",
        playlistName: "90年代ベスト",
        playlistId: "",
        artworkData: nil,
        nextTrackTitle: "Tomorrow never knows",
        nextArtistName: "Mr.Children",
        nextArtworkData: nil
    )
}

#Preview(as: .systemMedium) {
    SabiqueWidget()
} timeline: {
    NowPlayingEntry(
        date: .now,
        trackTitle: "どんなときも。（オリジナル・ヴァージョン）",
        artistName: "槇原敬之",
        playlistName: "90年代ベスト",
        playlistId: "",
        artworkData: nil,
        nextTrackTitle: "Tomorrow never knows",
        nextArtistName: "Mr.Children",
        nextArtworkData: nil
    )
}

#Preview(as: .systemLarge) {
    SabiqueWidget()
} timeline: {
    NowPlayingEntry(
        date: .now,
        trackTitle: "どんなときも。",
        artistName: "槇原敬之",
        playlistName: "90年代ベスト",
        playlistId: "",
        artworkData: nil,
        nextTrackTitle: "Tomorrow never knows",
        nextArtistName: "Mr.Children",
        nextArtworkData: nil
    )
}
