import AppKit
import WebKit

@MainActor
final class GrafanaSession: NSObject, WKNavigationDelegate {
    private(set) var webView: WKWebView
    private var window: NSWindow?
    private var configuredURL: URL?
    var authenticationChanged: ((Bool) -> Void)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func configure(baseURL: URL) {
        guard configuredURL != baseURL else { return }
        configuredURL = baseURL
        webView.load(URLRequest(url: baseURL))
    }

    func showLogin(baseURL: URL) {
        configure(baseURL: baseURL)
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Sign in to Grafana"
            window.contentView = webView
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hideLogin() {
        window?.orderOut(nil)
    }

    func fetch(path: String) async throws -> Data {
        guard let baseURL = configuredURL else { throw RadarError.notConfigured }
        if webView.url?.host != baseURL.host {
            webView.load(URLRequest(url: baseURL))
            try await waitForGrafanaHost(baseURL.host)
        }

        let basePath = baseURL.path == "/" ? "" : baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = basePath.isEmpty ? path : "/\(basePath)\(path)"
        let script = """
        const response = await fetch(path, {
          method: 'GET',
          credentials: 'include',
          headers: { 'Accept': 'application/json' },
          redirect: 'follow'
        });
        return {
          status: response.status,
          url: response.url,
          contentType: response.headers.get('content-type') || '',
          body: await response.text()
        };
        """

        guard let value = try await webView.callAsyncJavaScript(
            script,
            arguments: ["path": requestPath],
            in: nil,
            contentWorld: .page
        ) else {
            throw RadarError.invalidResponse
        }

        guard let response = value as? [String: Any],
              let status = response["status"] as? Int,
              let body = response["body"] as? String else {
            throw RadarError.invalidResponse
        }

        let finalURL = response["url"] as? String ?? ""
        let contentType = response["contentType"] as? String ?? ""
        if status == 401 || status == 403 || finalURL.contains("/login") || contentType.contains("text/html") {
            authenticationChanged?(false)
            throw RadarError.notAuthenticated
        }
        guard (200..<300).contains(status) else { throw RadarError.http(status, body) }
        authenticationChanged?(true)
        guard let data = body.data(using: .utf8) else { throw RadarError.invalidResponse }
        return data
    }

    private func waitForGrafanaHost(_ host: String?) async throws {
        for _ in 0..<40 {
            if webView.url?.host == host, !webView.isLoading { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw RadarError.notAuthenticated
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == configuredURL?.host else { return }
        Task {
            if (try? await fetch(path: "/api/user")) != nil {
                authenticationChanged?(true)
            }
        }
    }
}
