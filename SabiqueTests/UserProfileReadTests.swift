import Foundation
import Testing
@testable import Sabique

@MainActor
struct UserProfileReadTests {
    @Test func existingValidProfileKeepsItsStoredValues() throws {
        var decodeCount = 0
        let profile = try CommunityManager.decodeExistingUserProfile(
            documentExists: true,
            decode: {
                decodeCount += 1
                return try JSONDecoder().decode(UserProfile.self, from: validProfileData)
            }
        )

        #expect(decodeCount == 1)
        #expect(profile?.nickname == "Existing")
        #expect(profile?.publishedPlaylistCount == 7)
        #expect(profile?.lastPublishedMonth == "2026-09")
        #expect(profile?.isPremium == true)
        #expect(profile?.isBanned == true)
    }

    @Test func absentDocumentAllowsCreationWithoutDecoding() throws {
        var decodeCalled = false
        let profile = try CommunityManager.decodeExistingUserProfile(
            documentExists: false,
            decode: {
                decodeCalled = true
                throw ProfileReadFailure.unexpectedDecode
            }
        )

        #expect(profile == nil)
        #expect(!decodeCalled)
    }

    @Test func missingRequiredFieldThrowsInsteadOfAllowingCreation() {
        let data = Data("""
        {"createdAt":0,"publishedPlaylistCount":7,
         "lastPublishedMonth":"2026-09","isPremium":true}
        """.utf8)

        #expect(throws: DecodingError.self) {
            try CommunityManager.decodeExistingUserProfile(
                documentExists: true,
                decode: { try JSONDecoder().decode(UserProfile.self, from: data) }
            )
        }
    }

    @Test func wrongFieldTypeThrowsInsteadOfAllowingCreation() {
        let data = Data("""
        {"createdAt":0,"publishedPlaylistCount":"seven",
         "lastPublishedMonth":"2026-09","isPremium":true,"isBanned":false}
        """.utf8)

        #expect(throws: DecodingError.self) {
            try CommunityManager.decodeExistingUserProfile(
                documentExists: true,
                decode: { try JSONDecoder().decode(UserProfile.self, from: data) }
            )
        }
    }

    @Test func decodeErrorPropagatesUnchanged() {
        #expect(throws: ProfileReadFailure.unexpectedDecode) {
            try CommunityManager.decodeExistingUserProfile(
                documentExists: true,
                decode: { throw ProfileReadFailure.unexpectedDecode }
            )
        }
    }

    private var validProfileData: Data {
        Data("""
        {"nickname":"Existing","createdAt":0,"publishedPlaylistCount":7,
         "lastPublishedMonth":"2026-09","isPremium":true,"isBanned":true}
        """.utf8)
    }

    private enum ProfileReadFailure: Error, Equatable {
        case unexpectedDecode
    }
}
