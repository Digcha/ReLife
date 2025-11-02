//
//  BLEManager.swift
//  ReLife
//
//  Created by Codex on 2025-09-14.
//

import CoreBluetooth
import Foundation
import SwiftUI

/// Handles BLE discovery, connection, and data exchange with the ReLife_M1 wearable.
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEManager()

    @Published var isConnected = false
    @Published var isScanning = false
    @Published var lastError: String?
    @Published var receivedValue: Int = 0
    @Published private(set) var didSkipConnection: Bool = false

    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?

    private let targetPeripheralName = "ReLife_M1"

    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    /// Begins scanning for nearby BLE peripherals.
    func startScan() {
        guard centralManager != nil else {
            print("ℹ️ Central Manager noch nicht verfügbar – Scan wird später erneut versucht.")
            return
        }

        guard centralManager.state == .poweredOn else {
            print("⚠️ Scan abgebrochen – Bluetooth State: \(centralManager.state.rawValue)")
            return
        }

        if !isScanning {
            print("🔍 Scanne nach BLE-Geräten …")
            lastError = nil
            isScanning = true
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    /// Stops an active scan operation.
    func stopScan() {
        guard isScanning else { return }
        centralManager?.stopScan()
        isScanning = false
    }

    /// Allows the dashboard to be shown without an active BLE connection.
    func skipToDashboard() {
        didSkipConnection = true
        lastError = nil
        stopScan()
        if !isConnected {
            isConnected = true
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth eingeschaltet – starte Scan …")
            startScan()
        case .poweredOff:
            print("⚠️ Bluetooth ist aus – bitte aktivieren.")
            stopScan()
            if isConnected && !didSkipConnection {
                isConnected = false
            }
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
        self.peripheral?.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "Unbekannt"
        print("🔗 Verbunden mit \(name)")
        didSkipConnection = false
        isScanning = false
        isConnected = true
        lastError = nil
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Unbekannter Fehler"
        print("❌ Verbindung fehlgeschlagen: \(message) – starte Scan neu …")
        isConnected = false
        self.peripheral = nil
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Verbindung verloren – starte Scan neu …")
        self.peripheral = nil
        isConnected = false
        if let error = error {
            lastError = error.localizedDescription
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
        for service in services {
            print("🧩 Service gefunden: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            print("⚠️ Fehler beim Finden von Characteristics: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("📊 Characteristic: \(characteristic.uuid)")
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("⚠️ Fehler beim Lesen eines Werts: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value, let value = data.first else { return }
        DispatchQueue.main.async {
            self.receivedValue = Int(value)
        }
        print("📥 Wert empfangen: \(value)")
    }

    // MARK: - Write Support

    func sendCommand(_ value: UInt8) {
        guard let peripheral, let services = peripheral.services else { return }

        for service in services {
            for characteristic in service.characteristics ?? [] where characteristic.properties.contains(.writeWithoutResponse) {
                let data = Data([value])
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                print("📤 Gesendet: \(value)")
                return
            }
        }
    }
}
