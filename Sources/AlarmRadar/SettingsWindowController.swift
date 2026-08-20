import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let urlField = NSTextField()
    private let intervalField = NSTextField()
    private let filterField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let onSave: () -> Void
    private let onSignIn: () -> Void
    private let onTest: (@escaping (Result<Void, Error>) -> Void) -> Void

    init(onSave: @escaping () -> Void,
         onSignIn: @escaping () -> Void,
         onTest: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void) {
        self.onSave = onSave
        self.onSignIn = onSignIn
        self.onTest = onTest

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Alarm Radar Settings"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI(in: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        urlField.stringValue = Config.shared.grafanaURL?.absoluteString ?? ""
        intervalField.stringValue = String(Int(Config.shared.pollInterval))
        filterField.stringValue = Config.shared.alertFilter
        statusLabel.stringValue = ""
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI(in window: NSWindow) {
        let urlLabel = NSTextField(labelWithString: "Grafana URL")
        let intervalLabel = NSTextField(labelWithString: "Poll interval (seconds)")
        let filterLabel = NSTextField(labelWithString: "Alert filter")
        urlField.placeholderString = "https://grafana.example.com"
        intervalField.placeholderString = "60"
        filterField.placeholderString = #"{team="payments", severity=~"critical|warning"}"#

        let signIn = NSButton(title: "Sign in…", target: self, action: #selector(signInPressed))
        let test = NSButton(title: "Test connection", target: self, action: #selector(testPressed))
        let save = NSButton(title: "Save", target: self, action: #selector(savePressed))
        save.keyEquivalent = "\r"

        let buttonRow = NSStackView(views: [signIn, test, NSView(), save])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.setHuggingPriority(.defaultLow, for: .horizontal)

        let grid = NSGridView(views: [
            [urlLabel, urlField],
            [intervalLabel, intervalField],
            [filterLabel, filterField],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 420

        let filterHelp = NSTextField(wrappingLabelWithString: "Optional: use free text or Prometheus-style label matchers. Supported operators: =, !=, =~, !~. Multiple matchers are ANDed.")
        filterHelp.textColor = .secondaryLabelColor
        filterHelp.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let stack = NSStackView(views: [grid, filterHelp, statusLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -24),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            filterHelp.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func savePressed() {
        saveValues()
        onSave()
        window?.close()
    }

    @objc private func signInPressed() {
        saveValues()
        onSignIn()
    }

    @objc private func testPressed() {
        saveValues()
        statusLabel.stringValue = "Testing…"
        onTest { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success: self?.statusLabel.stringValue = "Connected successfully."
                case let .failure(error): self?.statusLabel.stringValue = error.localizedDescription
                }
            }
        }
    }

    private func saveValues() {
        let rawURL = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Config.shared.grafanaURL = normalizedURL(rawURL)
        Config.shared.pollInterval = TimeInterval(intervalField.integerValue)
        Config.shared.alertFilter = filterField.stringValue
    }

    private func normalizedURL(_ value: String) -> URL? {
        guard !value.isEmpty else { return nil }
        let candidate = value.contains("://") ? value : "https://\(value)"
        guard var components = URLComponents(string: candidate), components.host != nil else { return nil }
        while components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.url
    }
}
