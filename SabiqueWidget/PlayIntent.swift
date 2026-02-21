//
//  PlayIntent.swift
//  SabiqueWidget
//

import AppIntents
import Foundation

struct PlayCurrentTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Current Track"
    static var description: IntentDescription = "Sabiqueで現在のトラックを再生"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.yuki.Sabique")
        defaults?.set(true, forKey: "widget.playRequested")
        defaults?.synchronize()
        return .result()
    }
}
