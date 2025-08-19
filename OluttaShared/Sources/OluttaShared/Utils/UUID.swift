import Foundation

public extension UUID {
    static var v7: Self {
        var value = (
            UInt8(0),
            UInt8(0),
            UInt8(0),
            UInt8(0),
            UInt8(0),
            UInt8(0),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
            UInt8.random(in: 0 ... 255),
        )
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        value.0 = .init((timestamp >> 40) & 0xFF)
        value.1 = .init((timestamp >> 32) & 0xFF)
        value.2 = .init((timestamp >> 24) & 0xFF)
        value.3 = .init((timestamp >> 16) & 0xFF)
        value.4 = .init((timestamp >> 8) & 0xFF)
        value.5 = .init(timestamp & 0xFF)
        value.6 = (value.6 & 0x0F) | 0x70
        value.8 = (value.8 & 0x3F) | 0x80
        return .init(uuid: value)
    }
}
