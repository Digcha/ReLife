// NEW FILE
//  TLVParser.swift
//  ReLife
//
//  Parses ReLife M1 firmware TLV packets (bulk + single sample).

import Foundation

enum TLVParser {
    private static let sampleSize = 13

    static func parse(data: Data) -> [ReLifeSample] {
        guard !data.isEmpty else {
            debug("TLVParser: empty packet")
            return []
        }

        var offset = 0
        var samples: [ReLifeSample] = []

        while offset < data.count {
            let type = data[offset]
            offset += 1

            switch type {
            case 0x10: // bulk
                guard offset < data.count else {
                    debug("TLVParser: bulk count missing")
                    return samples
                }
                let count = Int(data[offset])
                offset += 1
                let required = count * sampleSize
                guard offset + required <= data.count else {
                    debug("TLVParser: bulk payload truncated (\(data.count) bytes, need \(required + offset))")
                    return samples
                }

                for i in 0..<count {
                    let start = offset + (i * sampleSize)
                    let end = start + sampleSize
                    if let sample = parseSample(from: data, range: start..<end) {
                        samples.append(sample)
                    }
                }
                offset += required

            case 0x01: // single TLV with length header
                guard offset < data.count else {
                    debug("TLVParser: single length missing")
                    return samples
                }
                let length = Int(data[offset])
                offset += 1

                guard length == sampleSize else {
                    debug("TLVParser: unexpected single length \(length)")
                    if offset + length <= data.count {
                        offset += length
                    } else {
                        return samples
                    }
                    continue
                }

                guard offset + sampleSize <= data.count else {
                    debug("TLVParser: single payload truncated")
                    return samples
                }

                let payloadRange = offset..<(offset + sampleSize)
                if let sample = parseSample(from: data, range: payloadRange) {
                    samples.append(sample)
                }
                offset += sampleSize

            default:
                debug("TLVParser: skip unknown type \(type)")
                if offset < data.count {
                    let length = Int(data[offset])
                    offset += 1
                    let skip = min(length, data.count - offset)
                    offset += skip
                }
            }
        }

        return samples
    }

    // MARK: - Helpers
    private static func parseSample(from data: Data, range: Range<Int>) -> ReLifeSample? {
        guard range.upperBound <= data.count else { return nil }
        let payload = data.subdata(in: range)

        guard
            let timestamp = readUInt32LE(payload, 0),
            let hr = readUInt16LE(payload, 4),
            let spo2 = payload.byte(at: 6),
            let tempRaw = readInt16LE(payload, 7),
            let steps = readUInt32LE(payload, 9)
        else {
            debug("TLVParser: invalid sample payload")
            return nil
        }

        return ReLifeSample(
            timestamp: timestamp,
            hr: hr,
            spo2: spo2,
            temp: Double(tempRaw) / 100.0,
            steps: steps
        )
    }

    private static func readUInt16LE(_ data: Data, _ offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readInt16LE(_ data: Data, _ offset: Int) -> Int16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        let value = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        return Int16(bitPattern: value)
    }

    private static func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}

private extension Data {
    func byte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < count else { return nil }
        return self[index(startIndex, offsetBy: offset)]
    }
}
