import CoreBluetooth
import SwiftUI

struct DeviceListView: View {
    @ObservedObject var bt: BluetoothManager

    private func displayName(_ p: CBPeripheral) -> String {
        let n = p.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "Unnamed device" : n
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(bt.connectionStateText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Devices") {
                if bt.discovered.isEmpty {
                    Text(bt.isScanning ? "Scanning…" : "No devices found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bt.discovered, id: \.identifier) { p in
                        Button {
                            bt.connect(p)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(p))
                                    Text(p.identifier.uuidString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Connect")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if bt.connectedPeripheral != nil {
                    Button("Disconnect") { bt.disconnect() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if bt.isScanning {
                    Button("Stop") { bt.stopScan() }
                } else {
                    Button("Scan") { bt.startScan() }
                        .disabled(!bt.isBluetoothOn)
                }
            }
        }
    }
}

