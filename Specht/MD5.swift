import Foundation
import CommonCrypto

class MD5 {
    static func string(s: String) -> String {
        let strData = s.data(using: String.Encoding.utf8)!
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
//        var result = [UInt8](count: digestLen, repeatedValue: 0)
        var result = [UInt8](repeating: 0, count: digestLen)
        
        _ = strData.withUnsafeBytes {
            CC_MD5($0.bindMemory(to: UInt8.self).baseAddress!, CC_LONG(strData.count), &result)
        }
        
        return hexString(result: result)
    }

    static func hexString(result: [UInt8]) -> String {
        let hash = NSMutableString(capacity: result.count * 2)
        for i in 0..<result.count {
            hash.appendFormat("%02x", result[i])
        }

        return String(stringLiteral: hash as String)
    }
}
