// NEW FILE
//  BluetoothManager.swift
//  ReLife
//
//  Handles discovery, connection, and notification processing for ReLife M1.

import CoreBluetooth
import Foundation
import SwiftUI

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    @Published private(set) var isConnected = false
    @Published private(set) var isScanning = false
    @Published private(set) var isConnecting = false
    @Published var lastError: String?
    @Published var didSkipConnection: Bool = false
    @Published var receivedValue: Int = 0

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private let centralQueue = DispatchQueue(label: "relife.bluetooth.central", qos: .userInitiated)
    private let parseQueue = DispatchQueue(label: "relife.bluetooth.parser", qos: .utility)
    private weak var sampleStore: SampleStore?

    private let targetPeripheralName = "ReLife_M1"

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: centralQueue, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
    }

    func configure(sampleStore: SampleStore) {
        self.sampleStore = sampleStore
    }

    // MARK: - Scan / Connect
    func startScan() {
        guard centralManager.state == .poweredOn else {
            debug("Scan aborted – Bluetooth state \(centralManager.state.rawValue)")
            return
        }
        guard !isScanning, peripheral == nil, !isConnecting else { return }
        DispatchQueue.main.async {
            self.lastError = nil
            self.isScanning = true
        }
        debug("Scanning for \(targetPeripheralName)")
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScan() {
        guard isScanning else { return }
        centralManager.stopScan()
        DispatchQueue.main.async { self.isScanning = false }
    }

    func skipToDashboard() {
        DispatchQueue.main.async {
            self.didSkipConnection = true
            self.lastError = nil
            self.peripheral = nil
            self.isConnected = false
        }
        stopScan()
    }

    /// Resets connection state and triggers a fresh scan (used after data wipe).
    func resetAfterDataClear() {
        centralQueue.async { [weak self] in
            guard let self else { return }
            if let p = peripheral {
                centralManager.cancelPeripheralConnection(p)
            }
            peripheral = nil
            DispatchQueue.main.async {
                self.didSkipConnection = false
                self.lastError = nil
                self.isConnected = false
                self.isConnecting = false
                self.isScanning = false
            }
            startScan()
        }
    }

    func resumeConnectionFlow() {
        DispatchQueue.main.async {
            self.didSkipConnection = false
            self.lastError = nil
            self.peripheral = nil
            self.isConnected = false
        }
        startScan()
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            debug("Bluetooth powered on – starting scan")
            startScan()
        case .poweredOff:
            debug("Bluetooth powered off")
            stopScan()
            DispatchQueue.main.async { self.isConnected = false }
        default:
            debug("Bluetooth state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard peripheral.name == targetPeripheralName else { return }
        guard self.peripheral == nil, !isConnecting else { return }
        debug("Discovered \(targetPeripheralName), connecting")
        stopScan()
        DispatchQueue.main.async { self.isConnecting = true }
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        debug("Connected to \(peripheral.name ?? targetPeripheralName) – MTU \(mtu)")
        DispatchQueue.main.async {
            self.didSkipConnection = false
            self.isScanning = false
            self.isConnected = true
            self.isConnecting = false
            self.lastError = nil
        }
        sampleStore?.startLiveSession()
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Unknown"
        DispatchQueue.main.async { self.lastError = message }
        debug("Connection failed: \(message)")
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
        }
        self.peripheral = nil
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error {
            DispatchQueue.main.async { self.lastError = error.localizedDescription }
            debug("Disconnected with error: \(error.localizedDescription)")
        } else {
            debug("Disconnected from \(peripheral.name ?? targetPeripheralName)")
        }
        self.peripheral = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
        }
        startScan()
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            debug("Service discovery error: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            debug("No services on peripheral")
            return
        }

        services.forEach { service in
            debug("Discovering characteristics for \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            debug("Characteristic discovery error: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.properties.contains(.notify) {
            debug("Subscribing notify for characteristic \(characteristic.uuid)")
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            debug("Notify error: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value, !data.isEmpty else { return }

        parseQueue.async { [weak self] in
            guard let self else { return }
            let parsed = TLVParser.parse(data: data)
            guard !parsed.isEmpty else { return }
            debug("Parsed \(parsed.count) samples")
            self.sampleStore?.append(parsed)
            if let last = parsed.last {
                DispatchQueue.main.async {
                    self.receivedValue = Int(last.hr)
                }
            }
        }
    }
}

