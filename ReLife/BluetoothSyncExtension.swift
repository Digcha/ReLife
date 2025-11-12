//
//  BluetoothSyncExtension.swift
//  ReLife
//
//  Adds shared connection state and a unified sync workflow on top of BLEManager.
//

import Combine
import CoreBluetooth
import Foundation
import ObjectiveC.runtime
import SwiftUI

#if canImport(App_Parser)
import App_Parser
#elseif canImport(TLVParser)
import TLVParser
#endif

typealias BluetoothManager = BLEManager

// MARK: - BluetoothConnectionStore

@MainActor
final class BluetoothConnectionStore: ObservableObject {
    static let shared = BluetoothConnectionStore()

    @Published var isScanning = false
    @Published var isConnecting = false
    @Published var isConnected = false

    @Published var syncInProgress = false
    @Published var newFileAlertPresented = false

    @Published var deviceName: String?
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastSyncTimestamp = "relife.sync.lastSyncTimestamp"
    }

    private init() {
        if let stored = defaults.object(forKey: Keys.lastSyncTimestamp) as? Double {
            lastSyncDate = Date(timeIntervalSince1970: stored)
        }
    }

    func updateLastSync(_ date: Date) {
        lastSyncDate = date
        defaults.set(date.timeIntervalSince1970, forKey: Keys.lastSyncTimestamp)
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - BluetoothManager Extension API

extension BluetoothManager {
    @MainActor
    var connectionStore: BluetoothConnectionStore {
        ensureSyncReady()
        return BluetoothConnectionStore.shared
    }

    @MainActor
    func manualSync() {
        connectionStore.newFileAlertPresented = false

        guard let connectedPeripheral = self.peripheral else {
            presentSyncError("Kein verbundenes Gerät vorhanden.")
            return
        }

        guard let writeCharacteristic = syncContext.writeCharacteristic else {
            presentSyncError("Keine Write-Characteristic gefunden.")
            return
        }

        syncContext.expectedSize = nil
        syncContext.incoming.removeAll(keepingCapacity: true)

        connectionStore.syncInProgress = true
        connectionStore.errorMessage = nil

        let command = Data("SYNC".utf8)
        connectedPeripheral.writeValue(command, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
    }

    @MainActor
    func dismissSyncPrompt() {
        connectionStore.newFileAlertPresented = false
    }
}

// MARK: - Observer Support

private final class SyncObserverContainer {
    var cancellables = Set<AnyCancellable>()
}

private struct ObserverKeys {
    static var observers = "relife.sync.observers"
}

extension BluetoothManager {
    private var syncObserverContainer: SyncObserverContainer {
        if let existing = objc_getAssociatedObject(self, &ObserverKeys.observers) as? SyncObserverContainer {
            return existing
        }
        let container = SyncObserverContainer()
        objc_setAssociatedObject(self,
                                 &ObserverKeys.observers,
                                 container,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return container
    }

    @MainActor
    private func ensureSyncReady() {
        _ = Self.syncHooksInstaller
        if syncObserverContainer.cancellables.isEmpty {
            let store = BluetoothConnectionStore.shared

            $isScanning
                .receive(on: DispatchQueue.main)
                .sink { scanning in store.isScanning = scanning }
                .store(in: &syncObserverContainer.cancellables)

            $isConnected
                .receive(on: DispatchQueue.main)
                .sink { connected in store.isConnected = connected }
                .store(in: &syncObserverContainer.cancellables)
        }
    }
}

// MARK: - Method Swizzling Infrastructure

private enum SyncUUID {
    static let service = CBUUID(string: "12345678-1234-5678-1234-56789ABCDEF0")
    static let notify = CBUUID(string: "EF01")
    static let write = CBUUID(string: "EF02")
}

private enum SyncMarkers {
    static let newFile = Data("NEW_FILE_AVAILABLE".utf8)
    static let syncStart = Data("SYNC_START".utf8)
    static let fileSize = Data("FILE_SIZE".utf8)
    static let eof = Data("EOF".utf8)
    static let syncDone = Data("SYNC_DONE".utf8)
}

private struct OriginalIMPs {
    static var didUpdateState: (@convention(c) (AnyObject, Selector, CBCentralManager) -> Void)?
    static var didDiscoverPeripheral: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral, NSDictionary, NSNumber) -> Void)?
    static var didConnect: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral) -> Void)?
    static var didDisconnect: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral, NSError?) -> Void)?
    static var didFailToConnect: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral, NSError?) -> Void)?
    static var didDiscoverCharacteristics: (@convention(c) (AnyObject, Selector, CBPeripheral, CBService, NSError?) -> Void)?
    static var didUpdateValue: (@convention(c) (AnyObject, Selector, CBPeripheral, CBCharacteristic, NSError?) -> Void)?
    static var didWriteValue: (@convention(c) (AnyObject, Selector, CBPeripheral, CBCharacteristic, NSError?) -> Void)?
}

extension BluetoothManager {
    fileprivate static let syncHooksInstaller: Void = {
        installSyncHooks()
    }()

    private static func storeAndSwizzle<IMP>(_ selector: Selector,
                                             swizzled: Selector,
                                             storage: inout IMP?,
                                             type: IMP.Type) {
        guard
            let originalMethod = class_getInstanceMethod(BluetoothManager.self, selector),
            let swizzledMethod = class_getInstanceMethod(BluetoothManager.self, swizzled)
        else { return }

        let originalIMP = method_getImplementation(originalMethod)
        storage = unsafeBitCast(originalIMP, to: IMP.self)
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    private static func installSyncHooks() {
        struct Token { static var installed = false }
        guard !Token.installed else { return }
        Token.installed = true

        storeAndSwizzle(#selector(CBCentralManagerDelegate.centralManagerDidUpdateState(_:)),
                        swizzled: #selector(relife_sync_centralManagerDidUpdateState(_:)),
                        storage: &OriginalIMPs.didUpdateState,
                        type: (@convention(c) (AnyObject, Selector, CBCentralManager) -> Void).self)

        storeAndSwizzle(#selector(CBCentralManagerDelegate.centralManager(_:didDiscover:advertisementData:rssi:)),
                        swizzled: #selector(relife_sync_centralManager(_:didDiscover:advertisementData:rssi:)),
                        storage: &OriginalIMPs.didDiscoverPeripheral,
                        type: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral, NSDictionary, NSNumber) -> Void).self)

        storeAndSwizzle(#selector(CBCentralManagerDelegate.centralManager(_:didConnect:)),
                        swizzled: #selector(relife_sync_centralManager(_:didConnect:)),
                        storage: &OriginalIMPs.didConnect,
                        type: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral) -> Void).self)

        storeAndSwizzle(#selector(CBCentralManagerDelegate.centralManager(_:didDisconnectPeripheral:error:)),
                        swizzled: #selector(relife_sync_centralManager(_:didDisconnectPeripheral:error:)),
                        storage: &OriginalIMPs.didDisconnect,
                        type: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral, NSError?) -> Void).self)

        storeAndSwizzle(#selector(CBCentralManagerDelegate.centralManager(_:didFailToConnect:error:)),
                        swizzled: #selector(relife_sync_centralManager(_:didFailToConnect:error:)),
                        storage: &OriginalIMPs.didFailToConnect,
                        type: (@convention(c) (AnyObject, Selector, CBCentralManager, CBPeripheral, NSError?) -> Void).self)

        storeAndSwizzle(NSSelectorFromString("peripheral:didDiscoverCharacteristicsForService:error:"),
                        swizzled: #selector(relife_sync_peripheral(_:didDiscoverCharacteristicsFor:error:)),
                        storage: &OriginalIMPs.didDiscoverCharacteristics,
                        type: (@convention(c) (AnyObject, Selector, CBPeripheral, CBService, NSError?) -> Void).self)

        storeAndSwizzle(NSSelectorFromString("peripheral:didUpdateValueForCharacteristic:error:"),
                        swizzled: #selector(relife_sync_peripheral(_:didUpdateValueFor:error:)),
                        storage: &OriginalIMPs.didUpdateValue,
                        type: (@convention(c) (AnyObject, Selector, CBPeripheral, CBCharacteristic, NSError?) -> Void).self)

        storeAndSwizzle(NSSelectorFromString("peripheral:didWriteValueForCharacteristic:error:"),
                        swizzled: #selector(relife_sync_peripheral(_:didWriteValueFor:error:)),
                        storage: &OriginalIMPs.didWriteValue,
                        type: (@convention(c) (AnyObject, Selector, CBPeripheral, CBCharacteristic, NSError?) -> Void).self)
    }
}

// MARK: - Swizzled Implementations

extension BluetoothManager {
    @objc
    private func relife_sync_centralManagerDidUpdateState(_ central: CBCentralManager) {
        OriginalIMPs.didUpdateState?(self, #selector(CBCentralManagerDelegate.centralManagerDidUpdateState(_:)), central)
        Task { @MainActor in
            if central.state != .poweredOn {
                connectionStore.isScanning = false
                connectionStore.isConnected = false
                connectionStore.isConnecting = false
            }
        }
    }

    @objc
    private func relife_sync_centralManager(_ central: CBCentralManager,
                                            didDiscover cbPeripheral: CBPeripheral,
                                            advertisementData: [String: Any],
                                            rssi RSSI: NSNumber) {
        OriginalIMPs.didDiscoverPeripheral?(self,
                                            #selector(CBCentralManagerDelegate.centralManager(_:didDiscover:advertisementData:rssi:)),
                                            central,
                                            cbPeripheral,
                                            advertisementData as NSDictionary,
                                            RSSI)

        Task { @MainActor in
            connectionStore.isScanning = false
            connectionStore.isConnecting = true
            connectionStore.deviceName = cbPeripheral.name ?? "ReLife_M1"
        }
    }

    @objc
    private func relife_sync_centralManager(_ central: CBCentralManager,
                                            didConnect cbPeripheral: CBPeripheral) {
        OriginalIMPs.didConnect?(self,
                                 #selector(CBCentralManagerDelegate.centralManager(_:didConnect:)),
                                 central,
                                 cbPeripheral)
        Task { @MainActor in
            connectionStore.isConnecting = false
            connectionStore.isConnected = true
            connectionStore.deviceName = cbPeripheral.name ?? "ReLife_M1"
            connectionStore.errorMessage = nil
        }
    }

    @objc
    private func relife_sync_centralManager(_ central: CBCentralManager,
                                            didDisconnectPeripheral cbPeripheral: CBPeripheral,
                                            error: Error?) {
        OriginalIMPs.didDisconnect?(self,
                                    #selector(CBCentralManagerDelegate.centralManager(_:didDisconnectPeripheral:error:)),
                                    central,
                                    cbPeripheral,
                                    error as NSError?)
        Task { @MainActor in
            connectionStore.isConnected = false
            connectionStore.isConnecting = false
            if syncContext.incoming.count > 0 || connectionStore.syncInProgress {
                presentSyncError("Übertragung abgebrochen.")
            } else {
                resetSyncState()
            }
        }
    }

    @objc
    private func relife_sync_centralManager(_ central: CBCentralManager,
                                            didFailToConnect cbPeripheral: CBPeripheral,
                                            error: Error?) {
        OriginalIMPs.didFailToConnect?(self,
                                       #selector(CBCentralManagerDelegate.centralManager(_:didFailToConnect:error:)),
                                       central,
                                       cbPeripheral,
                                       error as NSError?)
        Task { @MainActor in
            connectionStore.isConnecting = false
            connectionStore.errorMessage = error?.localizedDescription
        }
    }

    @objc
    private func relife_sync_peripheral(_ cbPeripheral: CBPeripheral,
                                        didDiscoverCharacteristicsFor service: CBService,
                                        error: Error?) {
        OriginalIMPs.didDiscoverCharacteristics?(self,
                                                 NSSelectorFromString("peripheral:didDiscoverCharacteristicsForService:error:"),
                                                 cbPeripheral,
                                                 service,
                                                 error as NSError?)

        guard error == nil, service.uuid == SyncUUID.service else { return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == SyncUUID.notify {
                syncContext.notifyCharacteristic = characteristic
            } else if characteristic.uuid == SyncUUID.write {
                syncContext.writeCharacteristic = characteristic
            }
        }
    }

    @objc
    private func relife_sync_peripheral(_ cbPeripheral: CBPeripheral,
                                        didUpdateValueFor characteristic: CBCharacteristic,
                                        error: Error?) {
        OriginalIMPs.didUpdateValue?(self,
                                     NSSelectorFromString("peripheral:didUpdateValueForCharacteristic:error:"),
                                     cbPeripheral,
                                     characteristic,
                                     error as NSError?)

        guard characteristic.uuid == SyncUUID.notify else { return }

        if let error {
            Task { @MainActor in self.presentSyncError("Fehler beim Lesen: \(error.localizedDescription)") }
            return
        }

        guard let value = characteristic.value else { return }
        Task { @MainActor in handleNotificationPayload(value) }
    }

    @objc
    private func relife_sync_peripheral(_ cbPeripheral: CBPeripheral,
                                        didWriteValueFor characteristic: CBCharacteristic,
                                        error: Error?) {
        OriginalIMPs.didWriteValue?(self,
                                    NSSelectorFromString("peripheral:didWriteValueForCharacteristic:error:"),
                                    cbPeripheral,
                                    characteristic,
                                    error as NSError?)

        guard characteristic.uuid == SyncUUID.write else { return }
        if let error {
            Task { @MainActor in presentSyncError("Senden fehlgeschlagen: \(error.localizedDescription)") }
        }
    }
}

// MARK: - Notification Handling

extension BluetoothManager {
    @MainActor
    private func handleNotificationPayload(_ data: Data) {
        if data == SyncMarkers.newFile {
            connectionStore.newFileAlertPresented = true
            connectionStore.errorMessage = nil
            resetSyncState(clearProgress: false)
            return
        }

        if data == SyncMarkers.eof || data == SyncMarkers.syncDone {
            finalizeTransfer()
            return
        }

        if data.starts(with: SyncMarkers.fileSize) {
            handleFileSizePayload(data)
            return
        }

        if data == SyncMarkers.syncStart {
            connectionStore.syncInProgress = true
            syncContext.incoming.removeAll(keepingCapacity: true)
            syncContext.expectedSize = nil
            return
        }

        syncContext.incoming.append(data)
    }

    @MainActor
    private func handleFileSizePayload(_ data: Data) {
        guard data.count >= SyncMarkers.fileSize.count + 2 else { return }
        let sizeBytes = data[SyncMarkers.fileSize.count..<SyncMarkers.fileSize.count + 2]
        let sizeValue = sizeBytes.withUnsafeBytes { $0.load(as: UInt16.self) }
        syncContext.expectedSize = Int(UInt16(littleEndian: sizeValue))
        syncContext.incoming.removeAll(keepingCapacity: true)
    }

    @MainActor
    private func finalizeTransfer() {
        guard connectionStore.syncInProgress else {
            resetSyncState()
            return
        }

        if let expected = syncContext.expectedSize,
           expected != syncContext.incoming.count {
            presentSyncError("Dateigröße stimmt nicht überein (\(syncContext.incoming.count) ≠ \(expected)).")
            return
        }

        do {
            let documents = try FileManager.default.url(for: .documentDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
            let binURL = documents.appendingPathComponent("relife_data.bin")
            let csvURL = documents.appendingPathComponent("relife_data.csv")

            if FileManager.default.fileExists(atPath: binURL.path) {
                try FileManager.default.removeItem(at: binURL)
            }
            try syncContext.incoming.write(to: binURL, options: .atomic)

#if canImport(App_Parser) || canImport(TLVParser)
            let records = parseReLifeTLVFile(at: binURL)
            exportToCSV(records: records, outputURL: csvURL)
#endif

            let now = Date()
            connectionStore.updateLastSync(now)
            NotificationCenter.default.post(name: .relifeDidRefreshFromSync, object: nil)
        } catch {
            presentSyncError("Speichern fehlgeschlagen: \(error.localizedDescription)")
            return
        }

        connectionStore.syncInProgress = false
        resetSyncState()
    }

    @MainActor
    private func presentSyncError(_ message: String) {
        connectionStore.syncInProgress = false
        connectionStore.errorMessage = message
        resetSyncState()
    }

    @MainActor
    private func resetSyncState(clearProgress: Bool = true) {
        if clearProgress {
            connectionStore.syncInProgress = false
        }
        syncContext.expectedSize = nil
        syncContext.incoming.removeAll(keepingCapacity: false)
    }
}

// MARK: - Sync Context Storage

private final class SyncContext {
    var incoming = Data()
    var expectedSize: Int?
    var notifyCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?
}

private struct AssociatedKeys {
    static var syncContext = "relife.sync.context"
}

extension BluetoothManager {
    fileprivate var syncContext: SyncContext {
        _ = Self.syncHooksInstaller
        if let stored = objc_getAssociatedObject(self, &AssociatedKeys.syncContext) as? SyncContext {
            return stored
        }
        let context = SyncContext()
        objc_setAssociatedObject(self,
                                 &AssociatedKeys.syncContext,
                                 context,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return context
    }
}

// MARK: - SwiftUI Showcase

struct BluetoothSyncContentView: View {
    @ObservedObject private var store = BluetoothConnectionStore.shared
    @ObservedObject private var manager = BluetoothManager.shared

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text(statusText)
                    .font(.title2.bold())

                if let name = store.deviceName {
                    Text("Gerät: \(name)")
                        .foregroundColor(.secondary)
                }

                if let lastSync = store.lastSyncDate {
                    Text("Letzter Sync: \(lastSync.formatted(date: .numeric, time: .shortened))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("Noch keine Daten synchronisiert.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button("Sync Data") {
                    Task { @MainActor in manager.manualSync() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.isConnected || store.syncInProgress)

                Spacer()
            }
            .padding()

            if store.syncInProgress {
                overlay
            }
        }
        .alert("Neue Datei erkannt",
               isPresented: Binding(
                get: { store.newFileAlertPresented },
                set: { newValue in
                    if !newValue {
                        Task { @MainActor in manager.dismissSyncPrompt() }
                    }
                }
               )) {
            Button("Abbrechen", role: .cancel) {
                Task { @MainActor in manager.dismissSyncPrompt() }
            }
            Button("Synchronisieren") {
                Task { @MainActor in manager.manualSync() }
            }
        } message: {
            Text("Das Board hat neue Daten. Jetzt synchronisieren?")
        }
        .alert("Fehler", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    Task { @MainActor in store.clearError() }
                }
            }
        )) {
            Button("OK", role: .cancel) {
                Task { @MainActor in store.clearError() }
            }
        } message: {
            Text(store.errorMessage ?? "Unbekannter Fehler.")
        }
    }

    private var statusText: String {
        if store.isConnected { return "Verbunden" }
        if store.isConnecting { return "Verbindung wird hergestellt…" }
        if store.isScanning { return "Suche nach Geräten…" }
        return "Nicht verbunden"
    }

    private var overlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView("Daten werden übertragen…")
                    .progressViewStyle(.circular)
                Text("Bitte warten…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }
}

#Preview {
    BluetoothSyncContentView()
}
