//
//  SettingsView.swift
//  Sabique
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = true
    @State private var developerTapCount = 0
    @State private var isDeveloperMode = false
    
    var body: some View {
        NavigationStack {
            List {
                if isDeveloperMode {
                    Section(String(localized: "playback_settings")) {
                        Toggle(isOn: $autoPlayOnOpen) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "auto_play"))
                                Text(String(localized: "auto_play_description"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(String(localized: "about_this_app")) {
                    Text(String(localized: "app_description"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section(String(localized: "legal_info")) {
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Text(String(localized: "privacy_policy"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Text(String(localized: "terms_of_use"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // フッター
                Section {
                } footer: {
                    VStack(spacing: 4) {
                        let fullVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                        let versionParts = fullVersion.split(separator: ".")
                        let version = versionParts.prefix(2).joined(separator: ".")
                        Text("Sabique \(version)")
                            .onTapGesture {
                                developerTapCount += 1
                                if developerTapCount >= 7 {
                                    withAnimation {
                                        isDeveloperMode.toggle()
                                    }
                                    developerTapCount = 0
                                }
                            }
                        Text("© 2026 Yuki Takagi")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(String(localized: "settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
