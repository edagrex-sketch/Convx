import Foundation
import WebKit
import Combine

@MainActor
public final class PoTokenService: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    public static let shared = PoTokenService()

    private var webView: WKWebView?
    public private(set) var streamingPoToken: String?
    private var isInitializing = false
    private var initCompletionHandlers: [(String?) -> Void] = []

    private let googleApiKey = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
    private let requestKey = "O43z0dpjhgX20SCx4KAo"
    private let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.3"

    override private init() {
        super.init()
    }

    /// Initializes BotGuard and mints a streaming PoToken
    public func start() {
        guard webView == nil && !isInitializing else { return }
        isInitializing = true
        print("[PoTokenService] Starting PoToken generation pipeline...")

        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(self, name: "PoTokenBridge")
        config.userContentController = ucc

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = userAgent
        wv.navigationDelegate = self
        self.webView = wv

        // Load po_token.html from app bundle
        var htmlContent: String?
        if let resUrl = Bundle.main.url(forResource: "po_token", withExtension: "html"),
           let content = try? String(contentsOf: resUrl, encoding: .utf8) {
            htmlContent = content
        } else if let moduleUrl = Bundle.module.url(forResource: "po_token", withExtension: "html"),
                  let content = try? String(contentsOf: moduleUrl, encoding: .utf8) {
            htmlContent = content
        }

        guard let html = htmlContent else {
            print("[PoTokenService] po_token.html not found in bundle resources")
            isInitializing = false
            return
        }

        // Inject JS bridge shim so po_token.html can communicate back to Swift
        let bridgeShim = """
        <script>
        window.PoTokenWebView = {
            downloadAndRunBotguard: function() {
                window.webkit.messageHandlers.PoTokenBridge.postMessage({action: 'downloadAndRunBotguard'});
            },
            onRunBotguardResult: function(res) {
                window.webkit.messageHandlers.PoTokenBridge.postMessage({action: 'onRunBotguardResult', data: res});
            },
            onJsInitializationError: function(err) {
                window.webkit.messageHandlers.PoTokenBridge.postMessage({action: 'onJsInitializationError', error: '' + err});
            },
            onMinterCreated: function() {
                window.webkit.messageHandlers.PoTokenBridge.postMessage({action: 'onMinterCreated'});
            },
            onObtainPoTokenResult: function(id, res) {
                window.webkit.messageHandlers.PoTokenBridge.postMessage({action: 'onObtainPoTokenResult', id: id, data: res});
            },
            onObtainPoTokenError: function(id, err) {
                window.webkit.messageHandlers.PoTokenBridge.postMessage({action: 'onObtainPoTokenError', id: id, error: '' + err});
            }
        };
        </script>
        """

        let modifiedHtml = html.replacingOccurrences(of: "<script>", with: "\(bridgeShim)\n<script>")
        wv.loadHTMLString(modifiedHtml, baseURL: URL(string: "https://www.youtube.com"))
    }

    public func getStreamingPoToken() async -> String? {
        if let token = streamingPoToken {
            return token
        }

        if !isInitializing {
            start()
        }

        return await withCheckedContinuation { continuation in
            initCompletionHandlers.append { token in
                continuation.resume(returning: token)
            }
        }
    }

    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[PoTokenService] po_token.html loaded, triggering downloadAndRunBotguard...")
        webView.evaluateJavaScript("window.PoTokenWebView.downloadAndRunBotguard();", completionHandler: nil)
    }

    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }

        switch action {
        case "downloadAndRunBotguard":
            handleDownloadAndRunBotguard()

        case "onRunBotguardResult":
            if let botguardResponse = body["data"] as? String {
                handleRunBotguardResult(botguardResponse)
            }

        case "onMinterCreated":
            handleMinterCreated()

        case "onObtainPoTokenResult":
            if let poTokenU8 = body["data"] as? String {
                handlePoTokenResult(poTokenU8)
            }

        case "onJsInitializationError", "onObtainPoTokenError":
            let err = body["error"] as? String ?? "unknown error"
            print("[PoTokenService] JS Error: \(err)")
            completeAll(with: nil)

        default:
            break
        }
    }

    // MARK: - BotGuard Step 1: Create
    private func handleDownloadAndRunBotguard() {
        Task {
            do {
                guard let url = URL(string: "https://www.youtube.com/api/jnn/v1/Create") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/json+protobuf", forHTTPHeaderField: "Content-Type")
                request.setValue(googleApiKey, forHTTPHeaderField: "x-goog-api-key")
                request.setValue("grpc-web-javascript/0.1", forHTTPHeaderField: "x-user-agent")
                request.httpBody = try JSONSerialization.data(withJSONObject: [requestKey])

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let rawJson = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
                    print("[PoTokenService] Create request failed")
                    completeAll(with: nil)
                    return
                }

                // Parse challenge data
                guard let challengeJsonString = self.parseChallengeData(rawJson) else {
                    print("[PoTokenService] Failed to parse challenge data")
                    completeAll(with: nil)
                    return
                }

                let js = """
                try {
                    var data = \(challengeJsonString);
                    runBotGuard(data).then(function (result) {
                        window.webPoSignalOutput = result.webPoSignalOutput;
                        window.PoTokenWebView.onRunBotguardResult(result.botguardResponse);
                    }, function (error) {
                        window.PoTokenWebView.onJsInitializationError(error + "\\n" + error.stack);
                    });
                } catch (error) {
                    window.PoTokenWebView.onJsInitializationError(error + "\\n" + error.stack);
                }
                """
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            } catch {
                print("[PoTokenService] Error in Create: \(error)")
                completeAll(with: nil)
            }
        }
    }

    // MARK: - BotGuard Step 2: GenerateIT
    private func handleRunBotguardResult(_ botguardResponse: String) {
        Task {
            do {
                guard let url = URL(string: "https://www.youtube.com/api/jnn/v1/GenerateIT") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/json+protobuf", forHTTPHeaderField: "Content-Type")
                request.setValue(googleApiKey, forHTTPHeaderField: "x-goog-api-key")
                request.setValue("grpc-web-javascript/0.1", forHTTPHeaderField: "x-user-agent")
                request.httpBody = try JSONSerialization.data(withJSONObject: [requestKey, botguardResponse])

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let itJson = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
                    print("[PoTokenService] GenerateIT failed")
                    completeAll(with: nil)
                    return
                }

                // Token is either at index 0 or index 3
                var tokenStr: String?
                if itJson.indices.contains(0), let t = itJson[0] as? String, !t.isEmpty {
                    tokenStr = t
                } else if itJson.indices.contains(3), let t = itJson[3] as? String, !t.isEmpty {
                    tokenStr = t
                }

                guard let integrityTokenB64 = tokenStr else {
                    print("[PoTokenService] Integrity token not found in GenerateIT response")
                    completeAll(with: nil)
                    return
                }

                let u8ArrayString = self.base64ToU8ArrayString(integrityTokenB64)
                let js = """
                try {
                    var itU8 = \(u8ArrayString);
                    createPoTokenMinter(window.webPoSignalOutput, itU8).then(function() {
                        window.PoTokenWebView.onMinterCreated();
                    }).catch(function(error) {
                        window.PoTokenWebView.onJsInitializationError(error + "\\n" + (error.stack || ''));
                    });
                } catch (error) {
                    window.PoTokenWebView.onJsInitializationError(error + "\\n" + error.stack);
                }
                """
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            } catch {
                print("[PoTokenService] Error in GenerateIT: \(error)")
                completeAll(with: nil)
            }
        }
    }

    // MARK: - BotGuard Step 3: Mint PoToken
    private func handleMinterCreated() {
        let identifier = "CuUwU7dBJuc"
        let u8Identifier = self.stringToU8ArrayString(identifier)
        let js = """
        try {
            var ident = \(u8Identifier);
            obtainPoToken(ident).then(function(poTokenU8) {
                var poStr = Array.from(poTokenU8).join(",");
                window.PoTokenWebView.onObtainPoTokenResult("\(identifier)", poStr);
            }).catch(function(error) {
                window.PoTokenWebView.onObtainPoTokenError("\(identifier)", error + "\\n" + (error.stack || ''));
            });
        } catch (error) {
            window.PoTokenWebView.onObtainPoTokenError("\(identifier)", error + "\\n" + error.stack);
        }
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func handlePoTokenResult(_ poTokenU8: String) {
        let bytes = poTokenU8.split(separator: ",").compactMap { UInt8($0) }
        let data = Data(bytes)
        let base64Token = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        self.streamingPoToken = base64Token
        self.isInitializing = false
        print("[PoTokenService] Successfully generated streaming PoToken! (len=\(base64Token.count))")
        completeAll(with: base64Token)
    }

    private func completeAll(with token: String?) {
        let handlers = self.initCompletionHandlers
        self.initCompletionHandlers.removeAll()
        for handler in handlers {
            handler(token)
        }
    }

    // MARK: - Parsing Helpers
    private func parseChallengeData(_ rawArray: [Any]) -> String? {
        var challengeData: [Any] = []
        if rawArray.count > 1, let scrambledB64 = rawArray[1] as? String {
            if let descrambled = descramble(scrambledB64),
               let descrambledData = descrambled.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: descrambledData) as? [Any] {
                challengeData = parsed
            }
        } else if let first = rawArray.first as? [Any] {
            challengeData = first
        }

        guard challengeData.count >= 8 else { return nil }

        let messageId = challengeData[0] as? String ?? ""
        let interpreterHash = challengeData[3] as? String ?? ""
        let program = challengeData[4] as? String ?? ""
        let globalName = challengeData[5] as? String ?? ""
        let clientExperimentsStateBlob = challengeData[7] as? String ?? ""

        var safeScript: String?
        if let scripts = challengeData[1] as? [Any] {
            safeScript = scripts.compactMap { $0 as? String }.first
        }

        var trustedUrl: String?
        if let urls = challengeData[2] as? [Any] {
            trustedUrl = urls.compactMap { $0 as? String }.first
        }

        let dict: [String: Any] = [
            "messageId": messageId,
            "interpreterJavascript": [
                "privateDoNotAccessOrElseSafeScriptWrappedValue": safeScript as Any,
                "privateDoNotAccessOrElseTrustedResourceUrlWrappedValue": trustedUrl as Any
            ],
            "interpreterHash": interpreterHash,
            "program": program,
            "globalName": globalName,
            "clientExperimentsStateBlob": clientExperimentsStateBlob
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    private func descramble(_ scrambled: String) -> String? {
        var b64 = scrambled.replacingOccurrences(of: "-", with: "+")
                           .replacingOccurrences(of: "_", with: "/")
                           .replacingOccurrences(of: ".", with: "=")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64) else { return nil }
        var out = [UInt8]()
        for byte in data {
            let shifted = (Int(byte) + 97) & 0xFF
            out.append(UInt8(shifted))
        }
        return String(data: Data(out), encoding: .utf8)
    }

    private func base64ToU8ArrayString(_ b64Str: String) -> String {
        var b64 = b64Str.replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")
                        .replacingOccurrences(of: ".", with: "=")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64) else { return "new Uint8Array([])" }
        let numbers = data.map { String($0) }.joined(separator: ",")
        return "new Uint8Array([\(numbers)])"
    }

    private func stringToU8ArrayString(_ str: String) -> String {
        let bytes = Array(str.utf8).map { String($0) }.joined(separator: ",")
        return "new Uint8Array([\(bytes)])"
    }
}
