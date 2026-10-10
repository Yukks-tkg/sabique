import Foundation
import Testing
@testable import Sabique

@MainActor
struct PlaybackOrderTests {
    private var ids: [UUID] {
        (1...4).map { UUID(uuidString: "00000000-0000-0000-0000-00000000000\($0)")! }
    }

    @Test func defaultsToSavedOrder() {
        var order = PlaybackOrder()
        order.start(trackIDs: ids)
        #expect(!order.isShuffled)
        #expect(order.trackIDs == ids)
        #expect(order.currentID == ids[0])
        #expect(order.nextID == ids[1])
        #expect(order.previousID == ids[3])
    }

    @Test func emptyOrderNeverProducesAnIndexOrTrack() {
        var order = PlaybackOrder()
        order.start(trackIDs: [])
        #expect(order.currentID == nil)
        #expect(order.next() == nil)
        #expect(order.previous() == nil)
        order.setShuffleEnabled(true, trackIDs: [])
        #expect(order.nextID == nil)
        #expect(order.previousID == nil)
    }

    @Test func oneTrackRepeatsInBothModes() {
        for shuffleEnabled in [false, true] {
            var order = PlaybackOrder()
            order.setShuffleEnabled(shuffleEnabled, trackIDs: [])
            order.start(trackIDs: [ids[0]])
            #expect(order.next() == ids[0])
            #expect(order.previous() == ids[0])
        }
    }

    @Test func shuffleVisitsEachIDOnceAndRepeatsTheSameCycle() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        let original = ids
        let shuffled = Array(ids.reversed())
        order.start(trackIDs: original, shuffle: { Array($0.reversed()) })

        var visited: [UUID] = []
        for _ in 0..<ids.count {
            if let id = order.currentID { visited.append(id) }
            order.next()
        }

        #expect(visited == shuffled)
        #expect(Set(visited) == Set(original))
        #expect(order.currentID == shuffled.first)
        #expect(original == ids) // The saved-order input was not mutated.
    }

    @Test func explicitlySelectedTrackStartsFirstWhenShuffled() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, selectedID: ids[1], shuffle: { Array($0.reversed()) })
        #expect(order.currentID == ids[1])
        #expect(order.trackIDs == [ids[1], ids[3], ids[2], ids[0]])
        #expect(Set(order.trackIDs).count == ids.count)
    }

    @Test func explicitlySelectedTrackKeepsItsPositionInNormalOrder() {
        var order = PlaybackOrder()
        order.start(trackIDs: ids, selectedID: ids[2])
        #expect(order.trackIDs == ids)
        #expect(order.currentID == ids[2])
        #expect(order.next() == ids[3])
    }

    @Test func missingSelectionFallsBackToFirstOfCurrentOrder() {
        var order = PlaybackOrder()
        order.start(trackIDs: ids, selectedID: UUID())
        #expect(order.currentID == ids.first)
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, selectedID: UUID(), shuffle: { Array($0.reversed()) })
        #expect(order.currentID == ids.last)
    }

    @Test func togglingOnKeepsCurrentTrackAndOnlyChangesFollowingOrder() {
        var order = PlaybackOrder()
        order.start(trackIDs: ids, selectedID: ids[1])
        order.setShuffleEnabled(true, trackIDs: ids, shuffle: { Array($0.reversed()) })
        #expect(order.currentID == ids[1])
        #expect(order.trackIDs == [ids[1], ids[3], ids[2], ids[0]])
        #expect(order.nextID == ids[3])
        #expect(order.next() == ids[3])
        #expect(order.previous() == ids[1])
    }

    @Test func togglingOffKeepsCurrentTrackAndRestoresSavedSuccessor() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, selectedID: ids[1], shuffle: { Array($0.reversed()) })
        order.setShuffleEnabled(false, trackIDs: ids)
        #expect(!order.isShuffled)
        #expect(order.currentID == ids[1])
        #expect(order.trackIDs == ids)
        #expect(order.nextID == ids[2])
    }

    @Test func settingSameModeDoesNotReshuffle() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, shuffle: { Array($0.reversed()) })
        var shuffleCalled = false
        order.setShuffleEnabled(true, trackIDs: ids, shuffle: {
            shuffleCalled = true
            return $0
        })
        #expect(!shuffleCalled)
        #expect(order.trackIDs == Array(ids.reversed()))
    }

    @Test func previousAndNextAreInversesIncludingWrapAround() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, shuffle: { Array($0.reversed()) })
        for _ in 0..<(ids.count * 2) {
            let before = order.currentID
            let peekedNext = order.nextID
            #expect(order.next() == peekedNext)
            #expect(order.previous() == before)
            order.next()
        }
        #expect(order.previous() == ids[0])
        #expect(order.next() == ids[3])
    }

    @Test func normalOrderUsesLiveSavedOrderWithoutChangingCurrentTrack() {
        var order = PlaybackOrder()
        order.start(trackIDs: ids, selectedID: ids[1])
        let reordered = [ids[3], ids[1], ids[0], ids[2]]
        order.synchronize(with: reordered)
        #expect(order.currentID == ids[1])
        #expect(order.trackIDs == reordered)
        #expect(order.nextID == ids[0])
    }

    @Test func savedReorderingDoesNotReshuffleTheCurrentCycle() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, shuffle: { Array($0.reversed()) })
        let queued = order.trackIDs
        order.synchronize(with: [ids[1], ids[3], ids[0], ids[2]])
        #expect(order.trackIDs == queued)
        #expect(order.currentID == ids[3])
        #expect(order.nextID == ids[2])
    }

    @Test func appendedTracksJoinTheCycleWithoutRepeatingExistingIDs() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: Array(ids.prefix(2)), shuffle: { Array($0.reversed()) })
        order.synchronize(with: ids)
        order.synchronize(with: ids)
        #expect(order.trackIDs == [ids[1], ids[0], ids[2], ids[3]])
        #expect(order.currentID == ids[1])
    }

    @Test func deletingNextTrackKeepsPeekAndActualNextConsistent() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids, shuffle: { Array($0.reversed()) })
        order.synchronize(with: [ids[0], ids[1], ids[3]])
        #expect(order.trackIDs == [ids[3], ids[1], ids[0]])
        #expect(order.currentID == ids[3])
        let widgetNext = order.nextID
        #expect(widgetNext == ids[1])
        #expect(order.next() == widgetNext)
    }

    @Test func deletingLastTrackStillWrapsSafely() {
        var order = PlaybackOrder()
        order.start(trackIDs: ids, selectedID: ids[2])
        order.synchronize(with: Array(ids.prefix(3)))
        #expect(order.nextID == ids[0])
        #expect(order.next() == ids[0])
        #expect(order.previous() == ids[2])
    }

    @Test func deletingCurrentTrackEndsTheSessionInBothModes() {
        for shuffleEnabled in [false, true] {
            var order = PlaybackOrder()
            order.setShuffleEnabled(shuffleEnabled, trackIDs: [])
            order.start(trackIDs: ids, selectedID: ids[1], shuffle: { Array($0.reversed()) })
            order.synchronize(with: [ids[0], ids[2], ids[3]])
            #expect(order.currentID == nil)
            #expect(order.nextID == nil)
            #expect(order.previous() == nil)
        }
    }

    @Test func stopClearsSessionButKeepsOnlyTheInMemoryMode() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        order.start(trackIDs: ids)
        order.stop()
        #expect(order.currentID == nil)
        #expect(order.trackIDs.isEmpty)
        #expect(order.isShuffled)
        #expect(!PlaybackOrder().isShuffled)
        order.start(trackIDs: ids, shuffle: { Array($0.reversed()) })
        #expect(order.currentID == ids[3])
    }

    @Test func repeatedInputIDsDoNotCreateDuplicateQueueEntries() {
        var order = PlaybackOrder()
        order.start(trackIDs: [ids[0], ids[0], ids[1]])
        #expect(order.trackIDs == [ids[0], ids[1]])
        #expect(order.next() == ids[1])
        #expect(order.next() == ids[0])
    }

    @Test func peekingAtWidgetNextDoesNotConsumeOrReshuffleIt() {
        var order = PlaybackOrder()
        order.setShuffleEnabled(true, trackIDs: [])
        var shuffleCount = 0
        order.start(trackIDs: ids, shuffle: {
            shuffleCount += 1
            return Array($0.reversed())
        })
        let first = order.currentID
        let next = order.nextID
        #expect(order.nextID == next)
        #expect(order.nextID == next)
        #expect(order.currentID == first)
        #expect(order.next() == next)
        #expect(shuffleCount == 1)
    }
}
