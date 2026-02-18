//
//  SabiqueWidget.swift
//  SabiqueWidget
//

import WidgetKit
import SwiftUI

// MARK: - データモデル

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let trackTitle: String
    let artistName: String
    let playlistName: String
    let artworkData: Data?
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
            artworkData: nil
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
        let artworkData = defaults?.data(forKey: "nowPlaying.artworkData")

        return NowPlayingEntry(
            date: .now,
            trackTitle: title,
            artistName: artist,
            playlistName: playlist,
            artworkData: artworkData
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
        default:
            smallView
        }
    }

    // MARK: Small (正方形)
    private var smallView: some View {
        ZStack {
            VStack(spacing: 8) {
                // レコード盤
                recordDisk(size: 100)

                // プレイリスト名
                Text(entry.playlistName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: Medium (横長)
    private var mediumView: some View {
        ZStack {
            HStack(spacing: 16) {
                // レコード盤
                recordDisk(size: 110)

                // 曲情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.playlistName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    Text(entry.trackTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(entry.artistName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    // Sabiqueロゴ文字
                    Text("Sabique")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: レコード盤コンポーネント
    private func recordDisk(size: CGFloat) -> some View {
        let grooveCount = 4

        return ZStack {
            // 一番外側: レコードの黒い本体
            Circle()
                .fill(Color(white: 0.08))
                .frame(width: size, height: size)

            // レコードの溝（同心円）
            ForEach(0..<grooveCount, id: \.self) { i in
                let ratio = 1.0 - Double(i) * 0.13
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: size * ratio, height: size * ratio)
            }

            // アートワーク（中央の丸いラベル部分）
            let labelSize = size * 0.52
            Group {
                if let data = entry.artworkData,
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

            // 中央の穴
            Circle()
                .fill(Color(white: 0.08))
                .frame(width: size * 0.07, height: size * 0.07)

            // 外枠のハイライト
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: size, height: size)
        }
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
                            Color.black.opacity(0.5)
                        }
                    } else {
                        Color.black
                    }
                }
                .widgetURL(URL(string: "sabique://open"))
        }
        .configurationDisplayName("Sabique")
        .description("最後に再生した曲をレコード風に表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
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
        artworkData: nil
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
        artworkData: nil
    )
}
