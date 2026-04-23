import Foundation

struct AlertThresholds: Equatable {
    var overTemp_C: Double = 60.0
    var overCurrent_A: Double = 10.0
    var underVoltage_V: Double = 9.0
    var overVoltage_V: Double = 12.0
}

enum AlertEvent: Equatable {
    case overTemp(actual_C: Double, limit_C: Double)
    case overCurrent(actual_A: Double, limit_A: Double)
    case underVoltage(actual_V: Double, limit_V: Double)
    case overVoltage(actual_V: Double, limit_V: Double)

    var title: String {
        switch self {
        case .overTemp: return "Over temperature"
        case .overCurrent: return "Over current"
        case .underVoltage: return "Under voltage"
        case .overVoltage: return "Over voltage"
        }
    }

    var message: String {
        switch self {
        case let .overTemp(actual, limit):
            return String(format: "Temperature %.2f°C exceeded %.2f°C", actual, limit)
        case let .overCurrent(actual, limit):
            return String(format: "Current %.2fA exceeded %.2fA", actual, limit)
        case let .underVoltage(actual, limit):
            return String(format: "Voltage %.3fV dropped below %.3fV", actual, limit)
        case let .overVoltage(actual, limit):
            return String(format: "Voltage %.3fV exceeded %.3fV", actual, limit)
        }
    }
}

enum AlertEvaluator {
    static func evaluate(_ t: Telemetry, thresholds: AlertThresholds) -> [AlertEvent] {
        var events: [AlertEvent] = []

        let tempC = t.temperature_C
        let currentA = abs(t.current_A)
        let voltageV = t.voltage_V

        if tempC > thresholds.overTemp_C {
            events.append(.overTemp(actual_C: tempC, limit_C: thresholds.overTemp_C))
        }
        if currentA > thresholds.overCurrent_A {
            events.append(.overCurrent(actual_A: currentA, limit_A: thresholds.overCurrent_A))
        }
        if voltageV < thresholds.underVoltage_V {
            events.append(.underVoltage(actual_V: voltageV, limit_V: thresholds.underVoltage_V))
        }
        if voltageV > thresholds.overVoltage_V {
            events.append(.overVoltage(actual_V: voltageV, limit_V: thresholds.overVoltage_V))
        }

        return events
    }
}

