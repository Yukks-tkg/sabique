//
//  ReportPlaylistView.swift
//  Sabique
//
//  プレイリスト報告画面
//

import SwiftUI
import FirebaseAuth

struct ReportPlaylistView: View {
    let playlist: CommunityPlaylist

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var authManager: AuthManager

    @State private var selectedReason: ReportReason = .nickname
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "report_category")) {
                    Picker(String(localized: "select_category"), selection: $selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.localizedName).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(String(localized: "report_reason_optional")) {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                }

                Section {
                    Button(action: { submitReport() }) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text(String(localized: "submit_report"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle(String(localized: "report_inappropriate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert(String(localized: "report_complete"), isPresented: $showingSuccess) {
                Button(String(localized: "ok")) {
                    dismiss()
                }
            } message: {
                Text(String(localized: "report_received"))
            }
            .alert(String(localized: "error"), isPresented: $showingError) {
                Button(String(localized: "ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitReport() {
        guard let userId = authManager.currentUser?.uid else {
            errorMessage = String(localized: "sign_in_to_report")
            showingError = true
            return
        }

        isSubmitting = true

        Task {
            do {
                try await communityManager.reportPlaylist(
                    playlistId: playlist.id ?? "",
                    reporterUserId: userId,
                    reason: selectedReason,
                    comment: comment.isEmpty ? nil : comment
                )

                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    let samplePlaylist = CommunityPlaylist(
        id: "sample",
        name: "髭男サビメドレー",
        authorId: "user123",
        authorName: "田中太郎",
        authorIsPremium: true,
        tracks: [],
        songIds: [],
        likeCount: 0,
        downloadCount: 0,
        createdAt: Date()
    )

    return ReportPlaylistView(playlist: samplePlaylist)
        .environmentObject(CommunityManager())
        .environmentObject(AuthManager())
}
