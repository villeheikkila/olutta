import Foundation

extension String {
    func decodeBase64() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func base64DecodedData() -> Data? {
        Data(base64Encoded: self)
    }
}
