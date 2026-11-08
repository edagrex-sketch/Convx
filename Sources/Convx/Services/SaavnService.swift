import Foundation
import CommonCrypto

public final class SaavnService: Sendable {
    public static let shared = SaavnService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    public struct SaavnStreamResult: Sendable {
        public let url: URL
        public let duration: Double?
    }

    /// Searches JioSaavn for a matching track and returns a direct 320kbps / 160kbps streaming URL with exact duration
    public func getStreamInfo(title: String, artist: String) async -> SaavnStreamResult? {
        let cleanTitle = cleanSearchTerm(title)
        let cleanArtist = cleanSearchTerm(artist)
        let query = "\(cleanTitle) \(cleanArtist)".trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty,
              var components = URLComponents(string: "https://www.jiosaavn.com/api.php") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "__call", value: "search.getResults"),
            URLQueryItem(name: "_format", value: "json"),
            URLQueryItem(name: "_marker", value: "0"),
            URLQueryItem(name: "api_version", value: "4"),
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "n", value: "5"),
            URLQueryItem(name: "q", value: query)
        ]

        guard let searchUrl = components.url else { return nil }

        var request = URLRequest(url: searchUrl)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("49.36.0.1", forHTTPHeaderField: "X-Forwarded-For")
        request.setValue("49.36.0.1", forHTTPHeaderField: "X-Real-IP")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("explicit_content=1", forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                return nil
            }

            // Find best matching track
            for item in results {
                guard let moreInfo = item["more_info"] as? [String: Any],
                      let encryptedUrl = moreInfo["encrypted_media_url"] as? String,
                      !encryptedUrl.isEmpty else {
                    continue
                }

                if let decryptedUrl = decryptDES(encryptedBase64: encryptedUrl),
                   let streamUrl = formatStreamUrl(decryptedUrl: decryptedUrl, moreInfo: moreInfo) {
                    var dur: Double? = nil
                    if let durStr = moreInfo["duration"] as? String, let sec = Double(durStr), sec > 0 {
                        dur = sec
                    } else if let durStr = item["duration"] as? String, let sec = Double(durStr), sec > 0 {
                        dur = sec
                    }
                    print("[SaavnService] Found high-quality stream for '\(title)': \(streamUrl.absoluteString) (duration: \(dur ?? 0)s)")
                    return SaavnStreamResult(url: streamUrl, duration: dur)
                }
            }
        } catch {
            print("[SaavnService] Search failed for '\(query)': \(error)")
        }

        return nil
    }

    public func getStreamUrl(title: String, artist: String) async -> URL? {
        let res = await getStreamInfo(title: title, artist: artist)
        return res?.url
    }

    private func formatStreamUrl(decryptedUrl: String, moreInfo: [String: Any]) -> URL? {
        guard decryptedUrl.hasPrefix("http") else { return nil }

        let supports320 = (moreInfo["320kbps"] as? String)?.lowercased() == "true"
        var formatted = decryptedUrl

        // Replace bitrate suffix with _320 or _160 if possible
        if supports320 {
            formatted = formatted.replacingOccurrences(of: "_96.mp4", with: "_320.mp4")
                                 .replacingOccurrences(of: "_160.mp4", with: "_320.mp4")
                                 .replacingOccurrences(of: "_48.mp4", with: "_320.mp4")
        } else {
            formatted = formatted.replacingOccurrences(of: "_96.mp4", with: "_160.mp4")
                                 .replacingOccurrences(of: "_48.mp4", with: "_160.mp4")
        }

        return URL(string: formatted)
    }

    private func decryptDES(encryptedBase64: String, keyString: String = "38346591") -> String? {
        guard let data = Data(base64Encoded: encryptedBase64),
              let keyData = keyString.data(using: .utf8) else {
            return nil
        }

        let bufferSize = data.count + kCCBlockSizeDES
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferBytes in
            data.withUnsafeBytes { dataBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmDES),
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                        keyBytes.baseAddress,
                        kCCKeySizeDES,
                        nil, // ECB mode has no IV
                        dataBytes.baseAddress,
                        data.count,
                        bufferBytes.baseAddress,
                        bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else { return nil }

        buffer.count = numBytesDecrypted
        return String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanSearchTerm(_ text: String) -> String {
        var cleaned = text
        // Remove text in parentheses or brackets like "(Official Video)", "[Remix]"
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\[[^]]*\\]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)official\\s*video", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)video\\s*oficial", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)audio\\s*oficial", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)lyrics?", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)letra", with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
