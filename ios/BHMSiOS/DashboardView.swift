import SwiftUI

struct DashboardView: View {
    let telemetry: Telemetry?
    let rawLine: String

    private func valueCard(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let t = telemetry {
                HStack(spacing: 12) {
                    valueCard(title: "Voltage", value: String(format: "%.3f", t.voltage_V), unit: "V")
                    valueCard(title: "Current", value: String(format: "%.3f", t.current_A), unit: "A")
                }
                valueCard(title: "Temperature", value: String(format: "%.2f", t.temperature_C), unit: "°C")
            } else {
                ContentUnavailableView("No telemetry yet",
                                       systemImage: "wave.3.right",
                                       description: Text("Connect to your device and start streaming frames."))
                    .frame(maxWidth: .infinity, minHeight: 180)
            }

            if !rawLine.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last raw line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rawLine)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Dashboard")
    }
}

