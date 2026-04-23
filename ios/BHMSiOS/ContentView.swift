import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var bt = BluetoothManager()

    @State private var alertsEnabled: Bool = true
    @State private var thresholds = AlertThresholds()

    @State private var lastAlertSignature: String = ""
    @State private var lastAlertTime: Date = .distantPast

    var body: some View {
        TabView {
            NavigationStack {
                DeviceListView(bt: bt)
            }
            .tabItem { Label("Connect", systemImage: "dot.radiowaves.left.and.right") }

            NavigationStack {
                DashboardView(telemetry: bt.lastTelemetry, rawLine: bt.lastRawLine)
                    .onChange(of: bt.lastTelemetry) { _, newValue in
                        guard alertsEnabled, let t = newValue else { return }
                        let events = AlertEvaluator.evaluate(t, thresholds: thresholds)
                        for e in events {
                            notifyIfNeeded(e)
                        }
                    }
            }
            .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }

            NavigationStack {
                AlertsView(thresholds: $thresholds, alertsEnabled: $alertsEnabled)
            }
            .tabItem { Label("Alerts", systemImage: "exclamationmark.triangle") }
        }
        .task {
            await requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Non-fatal; alerts can still be shown in-app later if needed.
        }
    }

    private func notifyIfNeeded(_ event: AlertEvent) {
        let now = Date()

        // Basic de-dupe: avoid spamming identical alerts every second.
        let signature = "\(event.title)|\(event.message)"
        if signature == lastAlertSignature, now.timeIntervalSince(lastAlertTime) < 15 {
            return
        }
        lastAlertSignature = signature
        lastAlertTime = now

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.message
        content.sound = .default

        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

