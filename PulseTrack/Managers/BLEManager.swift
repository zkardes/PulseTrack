import Foundation
import CoreBluetooth

/// Verbindet sich direkt per Bluetooth LE mit Herzfrequenz-Sensoren, die den
/// Standard "Heart Rate Service" (0x180D) unterstützen — z.B. Brustgurte,
/// Armbänder wie viele GEOID-Tracker. Liefert Live-BPM + Batteriestand.
@MainActor
final class BLEManager: NSObject, ObservableObject {

    @Published var isScanning = false
    @Published var discovered: [DiscoveredDevice] = []
    @Published var connectedDevice: DiscoveredDevice?
    @Published var liveHeartRate: Int?
    @Published var batteryLevel: Int?
    @Published var state: CBManagerState = .unknown

    /// Verlauf der Live-Messung (für Graph).
    @Published var liveSamples: [HeartRateSample] = []

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    // Standard-GATT UUIDs
    private let hrService  = CBUUID(string: "180D")
    private let hrMeasure  = CBUUID(string: "2A37")
    private let batService = CBUUID(string: "180F")
    private let batLevel   = CBUUID(string: "2A19")

    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
        fileprivate let peripheral: CBPeripheral
        static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Scan

    func startScan() {
        guard central.state == .poweredOn else { return }
        discovered.removeAll()
        isScanning = true
        central.scanForPeripherals(withServices: [hrService], options: nil)
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
    }

    func connect(_ device: DiscoveredDevice) {
        stopScan()
        peripheral = device.peripheral
        peripheral?.delegate = self
        central.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        connectedDevice = nil
        liveHeartRate = nil
        batteryLevel = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unbekanntes Gerät"
        let device = DiscoveredDevice(id: peripheral.identifier, name: name,
                                      rssi: RSSI.intValue, peripheral: peripheral)
        if !discovered.contains(device) { discovered.append(device) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedDevice = discovered.first { $0.id == peripheral.identifier }
            ?? DiscoveredDevice(id: peripheral.identifier, name: peripheral.name ?? "Gerät",
                                rssi: 0, peripheral: peripheral)
        peripheral.discoverServices([hrService, batService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectedDevice = nil
        liveHeartRate = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { service in
            if service.uuid == hrService {
                peripheral.discoverCharacteristics([hrMeasure], for: service)
            } else if service.uuid == batService {
                peripheral.discoverCharacteristics([batLevel], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        service.characteristics?.forEach { ch in
            if ch.uuid == hrMeasure {
                peripheral.setNotifyValue(true, for: ch)
            } else if ch.uuid == batLevel {
                peripheral.readValue(for: ch)
                peripheral.setNotifyValue(true, for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }

        if characteristic.uuid == hrMeasure {
            if let bpm = Self.parseHeartRate(data) {
                liveHeartRate = bpm
                liveSamples.append(HeartRateSample(date: Date(), bpm: Double(bpm)))
                if liveSamples.count > 300 { liveSamples.removeFirst() }
            }
        } else if characteristic.uuid == batLevel, let first = data.first {
            batteryLevel = Int(first)
        }
    }

    /// Parst das Heart Rate Measurement Format (GATT 0x2A37).
    static func parseHeartRate(_ data: Data) -> Int? {
        guard let flags = data.first else { return nil }
        let is16bit = (flags & 0x01) != 0
        if is16bit {
            guard data.count >= 3 else { return nil }
            return Int(data[1]) | (Int(data[2]) << 8)
        } else {
            guard data.count >= 2 else { return nil }
            return Int(data[1])
        }
    }
}
