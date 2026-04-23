import CoreBluetooth
import Foundation

@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Public state
    @Published var isBluetoothOn: Bool = false
    @Published var isScanning: Bool = false
    @Published var discovered: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var lastTelemetry: Telemetry?
    @Published var lastRawLine: String = ""
    @Published var connectionStateText: String = "Idle"

    // MARK: - UUIDs
    // HM-10 default UART-like service/characteristic:
    // - Service: 0xFFE0
    // - Characteristic: 0xFFE1 (notify + write)
    private let hm10Service = CBUUID(string: "FFE0")
    private let hm10Char = CBUUID(string: "FFE1")

    // Nordic UART Service (NUS) fallback (some BLE-UART firmwares use this)
    private let nusService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let nusTX = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Notify: device -> phone
    private let nusRX = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Write: phone -> device

    // MARK: - CoreBluetooth
    private var central: CBCentralManager!
    private var txChar: CBCharacteristic?
    private var rxChar: CBCharacteristic?

    // MARK: - Frame buffering
    private var buffer = Data()
    private let newline = "\n".data(using: .utf8)!

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard isBluetoothOn else { return }
        discovered.removeAll()
        connectionStateText = "Scanning…"
        isScanning = true
        // Scan for either HM-10 or NUS (some devices advertise only one).
        central.scanForPeripherals(withServices: [hm10Service, nusService], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScan() {
        isScanning = false
        central.stopScan()
        if connectedPeripheral == nil {
            connectionStateText = "Idle"
        }
    }

    func connect(_ peripheral: CBPeripheral) {
        stopScan()
        connectionStateText = "Connecting…"
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let p = connectedPeripheral else { return }
        central.cancelPeripheralConnection(p)
    }

    func sendText(_ text: String) {
        guard let p = connectedPeripheral,
              let rx = rxChar
        else { return }

        let data = Data(text.utf8)
        // HM-10 commonly supports writeWithoutResponse; NUS often uses withResponse.
        // Prefer withoutResponse when available.
        let type: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(data, for: rx, type: type)
    }

    private func upsertDiscovered(_ peripheral: CBPeripheral) {
        if let idx = discovered.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            discovered[idx] = peripheral
        } else {
            discovered.append(peripheral)
        }
        discovered.sort { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func ingestNotifyData(_ data: Data) {
        buffer.append(data)

        while let r = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<r.lowerBound)
            buffer.removeSubrange(buffer.startIndex...r.lowerBound) // remove through '\n'

            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            lastRawLine = line
            do {
                let t = try TelemetryParser.parseLine(line)
                lastTelemetry = t
            } catch {
                // Ignore parse errors; raw line remains visible for debugging.
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.isBluetoothOn = (central.state == .poweredOn)
            if !self.isBluetoothOn {
                self.connectionStateText = "Bluetooth is off"
                self.isScanning = false
                self.discovered.removeAll()
                self.connectedPeripheral = nil
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                   didDiscover peripheral: CBPeripheral,
                                   advertisementData: [String: Any],
                                   rssi RSSI: NSNumber) {
        Task { @MainActor in
            self.upsertDiscovered(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connectedPeripheral = peripheral
            self.connectionStateText = "Discovering services…"
            self.buffer.removeAll(keepingCapacity: true)
            self.txChar = nil
            self.rxChar = nil
            peripheral.delegate = self
            peripheral.discoverServices([self.hm10Service, self.nusService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                   didFailToConnect peripheral: CBPeripheral,
                                   error: Error?) {
        Task { @MainActor in
            self.connectionStateText = "Connect failed"
            self.connectedPeripheral = nil
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                   didDisconnectPeripheral peripheral: CBPeripheral,
                                   error: Error?) {
        Task { @MainActor in
            self.connectionStateText = "Disconnected"
            self.connectedPeripheral = nil
            self.txChar = nil
            self.rxChar = nil
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }
        for s in services {
            if s.uuid == hm10Service {
                peripheral.discoverCharacteristics([hm10Char], for: s)
            } else if s.uuid == nusService {
                peripheral.discoverCharacteristics([nusTX, nusRX], for: s)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        guard error == nil else { return }
        guard let chars = service.characteristics else { return }

        for c in chars {
            if service.uuid == hm10Service, c.uuid == hm10Char {
                // HM-10 uses the same characteristic for notify + write.
                txChar = c
                rxChar = c
            } else {
                if c.uuid == nusTX { txChar = c }
                if c.uuid == nusRX { rxChar = c }
            }
        }

        if let tx = txChar {
            peripheral.setNotifyValue(true, for: tx)
            Task { @MainActor in
                self.connectionStateText = "Connected"
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        guard error == nil else { return }
        guard let data = characteristic.value else { return }
        if characteristic.uuid == nusTX || characteristic.uuid == hm10Char {
            Task { @MainActor in
                self.ingestNotifyData(data)
            }
        }
    }
}

