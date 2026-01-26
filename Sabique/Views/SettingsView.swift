//
//  SettingsView.swift
//  Sabique
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = true
    @State private var developerTapCount = 0
    @State private var isDeveloperMode = false
    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var showingArtworkPicker = false
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // プレミアムセクション
                if storeManager.isPremium {
                    Section {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.85, blue: 0.3),
                                            Color(red: 1.0, green: 0.55, blue: 0.3),
                                            Color(red: 0.95, green: 0.35, blue: 0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(String(localized: "premium_badge"))
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    } header: {
                        Text(String(localized: "premium_status"))
                    }
                } else {
                    Section {
                        Button(action: { showingPaywall = true }) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.85, blue: 0.3),
                                                Color(red: 1.0, green: 0.55, blue: 0.3),
                                                Color(red: 0.95, green: 0.35, blue: 0.35)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(String(localized: "upgrade_to_premium"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: restorePurchases) {
                            HStack {
                                if isRestoring {
                                    ProgressView()
                                        .frame(width: 20)
                                } else {
                                    Image(systemName: "arrow.counterclockwise")
                                }
                                Text(String(localized: "restore_purchases"))
                                Spacer()
                            }
                        }
                        .disabled(isRestoring)
                    } header: {
                        Text(String(localized: "premium_section"))
                    }
                }
                
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
                
                Section(String(localized: "background_settings")) {
                    if !customBackgroundArtworkURLString.isEmpty, let url = URL(string: customBackgroundArtworkURLString) {
                        HStack {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text(String(localized: "custom_background_set"))
                                    .font(.headline)
                                Button(String(localized: "reset_to_random")) {
                                    customBackgroundArtworkURLString = ""
                                    UserDefaults.standard.removeObject(forKey: "customBackgroundSongId")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            Button(String(localized: "change")) {
                                showingArtworkPicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button(action: { showingArtworkPicker = true }) {
                            HStack {
                                Text(String(localized: "select_background_artwork"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(String(localized: "legal_info")) {
                    Link(destination: URL(string: "https://immense-engineer-7f8.notion.site/Privacy-Policy-Sabique-2ed0dee3bb098077b979d500914ffbba")!) {
                        HStack {
                            Text(String(localized: "privacy_policy"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://immense-engineer-7f8.notion.site/Terms-of-Use-Sabique-2ed0dee3bb098038983feb7ecea57f7a")!) {
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingArtworkPicker) {
                ArtworkPickerView()
            }
        }
    }
    
    private func restorePurchases() {
        isRestoring = true
        Task {
            await storeManager.restorePurchases()
            isRestoring = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
}

