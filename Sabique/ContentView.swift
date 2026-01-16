import SwiftUI
import MusicKit

struct MusicPlayerView: View {
    @State private var searchKeyword = ""
    @State private var songs: MusicItemCollection<Song> = []

    var body: some View {
        VStack {
            // 検索バー
            TextField("曲名を検索（例: Official髭男dism）", text: $searchKeyword)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onSubmit {
                    Task {
                        await searchMusic()
                    }
                }

            // 検索結果リスト
            List(songs) { song in
                Button(action: {
                    playSong(song)
                }) {
                    HStack {
                        // アートワークの表示
                        if let artwork = song.artwork {
                            ArtworkImage(artwork, width: 50)
                                .cornerRadius(4)
                        }
                        VStack(alignment: .leading) {
                            Text(song.title).font(.headline)
                            Text(song.artistName).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            // 起動時に許可をリクエスト
            Task {
                await MusicAuthorization.request()
            }
        }
    }

    // 音楽を検索する関数
    func searchMusic() async {
        do {
            var request = MusicCatalogSearchRequest(term: searchKeyword, types: [Song.self])
            request.limit = 10
            let response = try await request.response()
            self.songs = response.songs
        } catch {
            print("検索エラー: \(error)")
        }
    }

    // 音楽を再生する関数
    func playSong(_ song: Song) {
        Task {
            do {
                let player = SystemMusicPlayer.shared
                player.queue = [song]
                try await player.play()
            } catch {
                print("再生エラー: \(error)")
            }
        }
    }
}
