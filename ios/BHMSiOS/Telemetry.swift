import Foundation

struct Telemetry: Equatable {
    var voltage_mV: Int
    var current_mA: Int
    var temperature_cC: Int

    var voltage_V: Double { Double(voltage_mV) / 1000.0 }
    var current_A: Double { Double(current_mA) / 1000.0 }
    var temperature_C: Double { Double(temperature_cC) / 100.0 }
}

enum TelemetryParseError: Error {
    case empty
    case invalidFormat(String)
}

enum TelemetryParser {
    static func parseLine(_ line: String) throws -> Telemetry {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TelemetryParseError.empty }

        // Format A: "v_mV,i_mA,t_cC"
        if trimmed.contains(",") && !trimmed.contains("=") {
            let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { throw TelemetryParseError.invalidFormat(trimmed) }
            guard let v = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                  let i = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                  let t = Int(parts[2].trimmingCharacters(in: .whitespaces)) else {
                throw TelemetryParseError.invalidFormat(trimmed)
            }
            return Telemetry(voltage_mV: v, current_mA: i, temperature_cC: t)
        }

        // Format B: "V=12034,I=-850,T=2530" (order doesn't matter)
        if trimmed.contains("=") {
            var dict: [String: Int] = [:]
            let parts = trimmed.split(separator: ",").map(String.init)
            for p in parts {
                let kv = p.split(separator: "=", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                let key = kv[0].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let valStr = kv[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if let val = Int(valStr) {
                    dict[key] = val
                }
            }
            guard let v = dict["V"], let i = dict["I"], let t = dict["T"] else {
                throw TelemetryParseError.invalidFormat(trimmed)
            }
            return Telemetry(voltage_mV: v, current_mA: i, temperature_cC: t)
        }

        throw TelemetryParseError.invalidFormat(trimmed)
    }
}

