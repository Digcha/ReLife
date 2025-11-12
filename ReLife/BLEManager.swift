//
//  BLEManager.swift
//  ReLife
//
//  Created by Codex on 2025-09-14.
//

import CoreBluetooth
import Foundation
import SwiftUI

#if canImport(App_Parser)
import App_Parser
#elseif canImport(TLVParser)
import TLVParser
#else
struct TLVRecord {}
func parseReLifeTLVFile(at url: URL) -> [TLVRecord] {
    print("⚠️ TLV Parser Modul nicht eingebunden – Rückgabe leerer Datensätze.")
    return []
}

func exportToCSV(records: [TLVRecord], outputURL: URL) {
    print("⚠️ TLV Parser Modul nicht eingebunden – CSV Export übersprungen.")
}
#endif

/// Handles BLE discovery, connection, and data exchange with the ReLife M1 wearable.
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEManager()

    @Published var isConnected = false
    @Published var isScanning = false
    @Published var lastError: String?
    @Published var receivedValue: Int = 0

    @Published var syncInProgress = false
    @Published var lastFileCreatedAt: Date?
    @Published var lastSyncAt: Date?

    var syncProgress: Double? {
        guard let expectedFileSize, expectedFileSize > 0 else { return nil }
        return Double(incomingData.count) / Double(expectedFileSize)
    }

    private let targetPeripheralName = "ReLife_M1"
    private let defaults = UserDefaults.standard
    private let isoFormatter = ISO8601DateFormatter()

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    private var notifyCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    private var expectedFileSize: Int?
    private var incomingData = Data()

    private enum DefaultsKeys {
        static let lastFileCreatedAt = "relife.lastFileCreatedAt"
        static let lastSyncAt = "relife.lastSyncAt"
    }

    private enum UUIDs {
        static let service = CBUUID(string: "12345678-1234-5678-1234-56789ABCDEF0")
        static let notify = CBUUID(string: "EF01")
        static let write = CBUUID(string: "EF02")
    }

    override init() {
        super.init()
        loadPersistedTimestamps()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    // MARK: - Public API

    func startScan() {
        guard centralManager != nil else {
            print("ℹ️ Central Manager noch nicht verfügbar – Scan wird später erneut versucht.")
            return
        }

        guard centralManager.state == .poweredOn else {
            print("⚠️ Scan abgebrochen – Bluetooth State: \(centralManager.state.rawValue)")
            return
        }

        guard !isScanning else { return }
        print("🔍 Scanne nach BLE-Geräten …")
        lastError = nil
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        guard isScanning else { return }
        centralManager?.stopScan()
        isScanning = false
    }

    func resumeConnectionFlow() {
        lastError = nil
        peripheral = nil
        stopScan()
        isConnected = false
        startScan()
    }

    func requestSync() {
        guard let peripheral, let writeCharacteristic else {
            print("⚠️ Keine Write-Characteristic verfügbar – SYNC nicht gesendet.")
            return
        }
        let command = Data("SYNC".utf8)
        peripheral.writeValue(command, for: writeCharacteristic, type: .withResponse)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            print("⚠️ Bluetooth ist aus – bitte aktivieren.")
            stopScan()
            isConnected = false
        default:
            print("ℹ️ Bluetooth-Status: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard peripheral.name == targetPeripheralName else { return }

        print("✅ \(targetPeripheralName) gefunden – Verbinde …")
        stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "Unbekannt"
        print("🔗 Verbunden mit \(name)")
        isScanning = false
        isConnected = true
        lastError = nil
        peripheral.discoverServices([UUIDs.service])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        let message = error?.localizedDescription ?? "Unbekannter Fehler"
        print("❌ Verbindung fehlgeschlagen: \(message) – starte Scan neu …")
        isConnected = false
        self.peripheral = nil
        startScan()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("❌ Verbindung verloren – starte Scan neu …")
        self.peripheral = nil
        isConnected = false
        notifyCharacteristic = nil
        writeCharacteristic = nil
        if let error {
            lastError = error.localizedDescription
        }
        if syncInProgress || !incomingData.isEmpty {
            presentSyncError("Übertragung abgebrochen.")
        } else {
            resetTransferState()
        }
        startScan()
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            print("⚠️ Fehler beim Finden von Services: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        services
            .filter { $0.uuid == UUIDs.service }
            .forEach { peripheral.discoverCharacteristics([UUIDs.notify, UUIDs.write], for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            print("⚠️ Fehler beim Finden von Characteristics: \(error.localizedDescription)")
            return
        }

        guard service.uuid == UUIDs.service else { return }
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case UUIDs.notify:
                notifyCharacteristic = characteristic
                if !characteristic.isNotifying {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            case UUIDs.write:
                writeCharacteristic = characteristic
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            print("⚠️ Fehler beim Lesen eines Werts: \(error.localizedDescription)")
            presentSyncError("Fehler beim Lesen: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == UUIDs.notify,
              let value = characteristic.value else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleNotification(value)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == UUIDs.write else { return }
        if let error {
            presentSyncError("SYNC senden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Handling

    private func handleNotification(_ data: Data) {
        let syncStart = Data("SYNC_START".utf8)
        let fileInfo = Data("FILE_INFO".utf8)
        let syncDone = Data("SYNC_DONE".utf8)
        let eof = Data("EOF".utf8)
        let newFile = Data("NEW_FILE_AVAILABLE".utf8)

        if data == newFile {
            print("ℹ️ Board meldet neue Datei verfügbar.")
            return
        }

        if data == syncStart {
            print("🔄 Sync started…")
            syncInProgress = true
            incomingData.removeAll(keepingCapacity: true)
            expectedFileSize = nil
            return
        }

        if data.starts(with: fileInfo) {
            handleFileInfo(data, prefix: fileInfo)
            return
        }

        if data == syncDone || data == eof {
            completeTransfer()
            return
        }

        incomingData.append(data)
    }

    private func handleFileInfo(_ data: Data, prefix: Data) {
        let payload = data.dropFirst(prefix.count)
        guard payload.count >= 6 else {
            print("⚠️ FILE_INFO unvollständig.")
            return
        }

        let timestampBytes = payload.prefix(4)
        let sizeBytes = payload.dropFirst(4).prefix(2)

        let rawTimestamp = UInt32(littleEndian: timestampBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        let rawSize = UInt16(littleEndian: sizeBytes.withUnsafeBytes { $0.load(as: UInt16.self) })

        let created = Date(timeIntervalSince1970: TimeInterval(rawTimestamp))
        lastFileCreatedAt = created
        persist(created, key: DefaultsKeys.lastFileCreatedAt)

        expectedFileSize = Int(rawSize)
        incomingData.removeAll(keepingCapacity: true)
        print("ℹ️ FILE_INFO erhalten – Größe: \(expectedFileSize ?? 0) Bytes, erstellt am \(created).")
    }

    private func completeTransfer() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let documentsDirectory else {
            presentSyncError("Dokumentverzeichnis nicht gefunden.")
            resetTransferState()
            return
        }

        guard let expectedFileSize else {
            presentSyncError("Keine erwartete Dateigröße vorhanden.")
            resetTransferState()
            return
        }

        guard incomingData.count == expectedFileSize else {
            presentSyncError("Dateigröße stimmt nicht überein (\(incomingData.count) ≠ \(expectedFileSize)).")
            resetTransferState()
            return
        }

        let binURL = documentsDirectory.appendingPathComponent("relife_data.bin")
        let csvURL = documentsDirectory.appendingPathComponent("relife_data.csv")

        do {
            if FileManager.default.fileExists(atPath: binURL.path) {
                try FileManager.default.removeItem(at: binURL)
            }
            try incomingData.write(to: binURL, options: .atomic)

            let records = parseReLifeTLVFile(at: binURL)
            exportToCSV(records: records, outputURL: csvURL)

            let now = Date()
            lastSyncAt = now
            persist(now, key: DefaultsKeys.lastSyncAt)

            NotificationCenter.default.post(name: .relifeDidRefreshFromSync, object: nil)
            print("✅ Sync abgeschlossen – CSV exportiert.")
        } catch {
            presentSyncError("Speichern fehlgeschlagen: \(error.localizedDescription)")
        }

        resetTransferState()
    }

    private func resetTransferState() {
        syncInProgress = false
        expectedFileSize = nil
        incomingData.removeAll(keepingCapacity: false)
    }

    private func presentSyncError(_ message: String) {
        lastError = message
        print("⚠️ Sync-Fehler: \(message)")
        resetTransferState()
    }

    // MARK: - Persistence

    private func persist(_ date: Date?, key: String) {
        guard let date else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(isoFormatter.string(from: date), forKey: key)
    }

    private func loadPersistedTimestamps() {
        if let createdString = defaults.string(forKey: DefaultsKeys.lastFileCreatedAt),
           let date = isoFormatter.date(from: createdString) {
            lastFileCreatedAt = date
        }
        if let syncString = defaults.string(forKey: DefaultsKeys.lastSyncAt),
           let date = isoFormatter.date(from: syncString) {
            lastSyncAt = date
        }
    }
}

extension Notification.Name {
    static let relifeDidRefreshFromSync = Notification.Name("relifeDidRefreshFromSync")
}
