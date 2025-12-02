// NEW FILE
//  ReLifeSample.swift
//  ReLife
//
//  Lightweight model for decoded firmware samples.

import Foundation

func debug(_ msg: String) {
    print("[ReLife DEBUG] \(msg)")
}

struct ReLifeSample: Codable, Hashable, Identifiable {
    let timestamp: UInt32
    let hr: UInt16
    let spo2: UInt8
    let temp: Double  // already divided by 100 on ingest
    let steps: UInt32

    var id: UInt32 { timestamp }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    var normalizedSteps: UInt32 {
        steps == 123 ? 0 : steps
    }

    func toUISample() -> Sample {
        Sample(
            timestamp: date,
            hr: Int(hr),
            spo2: Int(spo2),
            skinTempC: temp,
            steps: Int(normalizedSteps),
            id: "\(timestamp)"
        )
    }
}
