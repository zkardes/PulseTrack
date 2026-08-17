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
    @Published var statusText: String = ""

    /// Verlauf der Live-Messung (für Graph).
    @Published var liveSamples: [HeartRateSample] = []

    private var central: CBCentralManager!
    /// Starke Referenzen — sonst verwirft Core Bluetooth verbindende Peripherals.
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?

    // Standard-GATT UUIDs
    private let hrService  = CBUUID(string: "180D")
    private let hrMeasure  = CBUUID(string: "2A37")
    private let batService = CBUUID(string: "180F")
    private let batLevel   = CBUUID(string: "2A19")

    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        var name: String
        var rssi: Int
        var advertisesHR: Bool
        static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Scan

    func startScan() {
        guard central.state == .poweredOn else {
            statusText = "Bluetooth ist nicht bereit."
            return
        }
        discovered.removeAll()
        isScanning = true
        statusText = "Suche läuft…"

        // 1) Bereits mit dem System verbundene HR-Geräte einbeziehen
        //    (z.B. wenn der Tracker schon anderweitig verbunden ist).
        for p in central.retrieveConnectedPeripherals(withServices: [hrService]) {
            addOrUpdate(peripheral: p, name: p.name, rssi: 0, advertisesHR: true)
        }

        // 2) Ungefilterter Scan, damit auch Geräte auftauchen, die den
        //    Heart-Rate-Service nicht im Advertising ankündigen.
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        // Nach 15s automatisch stoppen (Akku schonen).
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await MainActor.run {
                if self?.isScanning == true { self?.stopScan() }
            }
        }
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        if discovered.isEmpty {
            statusText = "Kein Sensor gefunden. Stelle sicher, dass der Tracker eingeschaltet, in der Nähe und NICHT bereits in einer anderen App/den iOS-Einstellungen verbunden ist."
        } else {
            statusText = "\(discovered.count) Gerät(e) gefunden."
        }
    }

    func connect(_ device: DiscoveredDevice) {
        guard let p = peripherals[device.id] else { return }
        stopScan()
        statusText = "Verbinde mit \(device.name)…"
        activePeripheral = p
        p.delegate = self
        central.connect(p, options: nil)
    }

    func disconnect() {
        if let p = activePeripheral { central.cancelPeripheralConnection(p) }
        connectedDevice = nil
        liveHeartRate = nil
        batteryLevel = nil
    }

    // MARK: - Helpers

    private func addOrUpdate(peripheral: CBPeripheral, name: String?, rssi: Int, advertisesHR: Bool) {
        peripherals[peripheral.identifier] = peripheral
        let displayName = name ?? peripheral.name ?? "Unbekanntes Gerät"

        if let idx = discovered.firstIndex(where: { $0.id == peripheral.identifier }) {
            discovered[idx].rssi = rssi
            if advertisesHR { discovered[idx].advertisesHR = true }
            if discovered[idx].name == "Unbekanntes Gerät", displayName != "Unbekanntes Gerät" {
                discovered[idx].name = displayName
            }
        } else {
            discovered.append(DiscoveredDevice(id: peripheral.identifier, name: displayName,
                                               rssi: rssi, advertisesHR: advertisesHR))
        }
        // HR-Geräte nach oben sortieren, dann nach Signalstärke.
        discovered.sort { ($0.advertisesHR ? 1 : 0, $0.rssi) > ($1.advertisesHR ? 1 : 0, $1.rssi) }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        switch central.state {
        case .poweredOff: statusText = "Bitte Bluetooth aktivieren."
        case .unauthorized: statusText = "Bluetooth-Zugriff wurde nicht erlaubt (Einstellungen prüfen)."
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Advertisierte Service-UUIDs prüfen: enthält Heart Rate Service?
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisesHR = serviceUUIDs.contains(hrService)

        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        // Namenlose, nicht-HR-Geräte ignorieren, um die Liste sauber zu halten.
        if peripheral.name == nil && advName == nil && !advertisesHR { return }

        addOrUpdate(peripheral: peripheral, name: peripheral.name ?? advName,
                    rssi: RSSI.intValue, advertisesHR: advertisesHR)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusText = "Verbunden. Suche Herzfrequenz-Service…"
        connectedDevice = discovered.first { $0.id == peripheral.identifier }
            ?? DiscoveredDevice(id: peripheral.identifier, name: peripheral.name ?? "Gerät",
                                rssi: 0, advertisesHR: true)
        peripheral.discoverServices([hrService, batService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        statusText = "Verbindung fehlgeschlagen: \(error?.localizedDescription ?? "unbekannt")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectedDevice = nil
        liveHeartRate = nil
        statusText = "Verbindung getrennt."
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services = peripheral.services ?? []
        if !services.contains(where: { $0.uuid == hrService }) {
            statusText = "Dieses Gerät bietet kein Standard-Herzfrequenzprofil (0x180D)."
        }
        services.forEach { service in
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
                statusText = "Live-Herzfrequenz aktiv."
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
