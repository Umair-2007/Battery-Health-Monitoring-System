import SwiftUI

struct AlertsView: View {
    @Binding var thresholds: AlertThresholds
    @Binding var alertsEnabled: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Enable alerts", isOn: $alertsEnabled)
            } footer: {
                Text("Alerts are evaluated on the phone using the latest telemetry sample.")
            }

            Section("Thresholds") {
                HStack {
                    Text("Over-temp")
                    Spacer()
                    TextField("°C", value: $thresholds.overTemp_C, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 110)
                }

                HStack {
                    Text("Over-current")
                    Spacer()
                    TextField("A", value: $thresholds.overCurrent_A, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 110)
                }

                HStack {
                    Text("Under-voltage")
                    Spacer()
                    TextField("V", value: $thresholds.underVoltage_V, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 110)
                }

                HStack {
                    Text("Over-voltage")
                    Spacer()
                    TextField("V", value: $thresholds.overVoltage_V, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 110)
                }
            }
        }
        .navigationTitle("Alerts")
    }
}

