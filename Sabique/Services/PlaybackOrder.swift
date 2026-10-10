import Foundation

/// Session-only playback order. Never changes the saved playlist order.
struct PlaybackOrder {
    private(set) var isShuffled = false
    private(set) var trackIDs: [UUID] = []
    private(set) var currentID: UUID?

    var nextID: UUID? { adjacentID(offset: 1) }
    var previousID: UUID? { adjacentID(offset: -1) }

    mutating func start(
        trackIDs savedIDs: [UUID],
        selectedID: UUID? = nil,
        shuffle: ([UUID]) -> [UUID] = { $0.shuffled() }
    ) {
        trackIDs = unique(savedIDs)
        if isShuffled {
            trackIDs = shuffle(trackIDs)
        }
        if let selectedID, let index = trackIDs.firstIndex(of: selectedID) {
            // An explicit row/widget selection always starts with that track.
            if isShuffled {
                trackIDs.remove(at: index)
                trackIDs.insert(selectedID, at: 0)
            }
            currentID = selectedID
        } else {
            currentID = trackIDs.first
        }
    }

    mutating func setShuffleEnabled(
        _ enabled: Bool,
        trackIDs savedIDs: [UUID],
        shuffle: ([UUID]) -> [UUID] = { $0.shuffled() }
    ) {
        synchronize(with: savedIDs)
        guard enabled != isShuffled else { return }
        isShuffled = enabled
        let savedIDs = unique(savedIDs)
        if enabled {
            let remaining = savedIDs.filter { $0 != currentID }
            trackIDs = currentID.map { [$0] } ?? []
            trackIDs += shuffle(remaining)
        } else {
            trackIDs = savedIDs
        }
        // Keep currentID unchanged: a mode toggle must not restart the audio.
    }

    /// Reorders normally, or preserves the shuffled cycle while pruning removed
    /// tracks and appending newly added tracks. Deleting the current item stops
    /// the session rather than guessing a replacement for a deleted model.
    mutating func synchronize(with savedIDs: [UUID]) {
        let savedIDs = unique(savedIDs)
        let available = Set(savedIDs)
        if isShuffled {
            trackIDs.removeAll { !available.contains($0) }
            let queued = Set(trackIDs)
            trackIDs += savedIDs.filter { !queued.contains($0) }
        } else {
            trackIDs = savedIDs
        }
        if let currentID, !available.contains(currentID) {
            self.currentID = nil
        }
    }

    @discardableResult
    mutating func next() -> UUID? {
        currentID = nextID
        return currentID
    }

    @discardableResult
    mutating func previous() -> UUID? {
        currentID = previousID
        return currentID
    }

    mutating func stop() {
        trackIDs = []
        currentID = nil
        // Keep the in-memory mode choice until the app is relaunched or toggled.
    }

    private func adjacentID(offset: Int) -> UUID? {
        guard let currentID, let index = trackIDs.firstIndex(of: currentID) else {
            return nil
        }
        return trackIDs[(index + offset + trackIDs.count) % trackIDs.count]
    }

    private func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
