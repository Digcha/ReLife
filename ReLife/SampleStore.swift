// NEW FILE
//  SampleStore.swift
//  ReLife
//
//  Persists firmware samples, deduplicates, and publishes UI-ready snapshots.

import Foundation
import Combine

final class SampleStore: ObservableObject {
    @Published private(set) var samples: [ReLifeSample] = []
    @Published private(set) var isLoading: Bool = true

    private let queue = DispatchQueue(label: "relife.sample.store", qos: .utility)
    private let storageURL: URL
    private var storage: [ReLifeSample] = []
    private var index: Set<UInt32> = []
    private var hasSeenLiveData = false

    init(fileName: String = "relife_samples.json") {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        storageURL = folder.appendingPathComponent(fileName)
        loadFromDisk()
    }

    /// Clears the in-memory store when a new BLE session begins so incoming data
    /// can accumulate from a clean slate (avoids carrying over stale runs).
    func startLiveSession() {
        queue.async { [weak self] in
            guard let self else { return }
            self.hasSeenLiveData = false
            self.storage.removeAll()
            self.index.removeAll()
            DispatchQueue.main.async { [weak self] in
                self?.samples = []
                self?.isLoading = true
            }
        }
    }

    /// Removes all samples and the persisted cache. Used when user selects
    /// "Delete All Data".
    func resetAll() {
        queue.async { [weak self] in
            guard let self else { return }
            self.hasSeenLiveData = false
            self.storage.removeAll()
            self.index.removeAll()
            do {
                try FileManager.default.removeItem(at: storageURL)
                debug("SampleStore: deleted cache file")
            } catch {
                debug("SampleStore: cache delete failed (\(error.localizedDescription))")
            }
            DispatchQueue.main.async { [weak self] in
                self?.samples = []
                self?.isLoading = false
            }
        }
    }

    func append(_ incoming: [ReLifeSample]) {
        guard !incoming.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            hasSeenLiveData = true
            // Replace the entire store with the most recent packet payload.
            let sanitized = incoming.map {
                ReLifeSample(
                    timestamp: $0.timestamp,
                    hr: $0.hr,
                    spo2: $0.spo2,
                    temp: $0.temp,
                    steps: $0.normalizedSteps
                )
            }

            storage = sanitized.sorted { $0.timestamp < $1.timestamp }
            index = Set(storage.map { $0.timestamp })
            persistToDisk()
            publish(storage)
        } // queue

        // Even if nothing new was inserted (e.g. duplicate packets), make sure we
        // stop showing the loading state once the first packets arrive.
        queue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }
    }

    func reloadFromDisk() {
        loadFromDisk()
    }

    // MARK: - Private
    private func publish(_ items: [ReLifeSample]) {
        DispatchQueue.main.async { [weak self] in
            self?.samples = items
            self?.isLoading = false
        }
    }

    private func loadFromDisk() {
        queue.async { [weak self] in
            guard let self else { return }
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                }
            }
            if self.hasSeenLiveData {
                debug("SampleStore load skipped due to live data already present")
                return
            }
            do {
                let data = try Data(contentsOf: self.storageURL)
                let decoded = try JSONDecoder().decode([ReLifeSample].self, from: data)
                self.storage = decoded
                self.index = Set(decoded.map { $0.timestamp })
                self.publish(decoded)
                debug("SampleStore loaded \(decoded.count) samples from disk")
            } catch {
                debug("SampleStore load failed: \(error.localizedDescription)")
                self.publish([])
            }
        }
    }

    private func persistToDisk() {
        do {
            let data = try JSONEncoder().encode(storage)
            try data.write(to: storageURL, options: .atomic)
            debug("SampleStore persisted \(storage.count) samples")
        } catch {
            debug("SampleStore persist failed: \(error.localizedDescription)")
        }
    }
}
