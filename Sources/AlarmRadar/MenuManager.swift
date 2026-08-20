import AppKit

@MainActor
final class MenuManager: NSObject, NSMenuDelegate {
    private enum ConnectionState {
        case idle
        case checking
        case connected(Date)
        case failed(String)

        var color: NSColor {
            switch self {
            case .idle: return .secondaryLabelColor
            case .checking: return .systemOrange
            case .connected: return .systemGreen
            case .failed: return .systemRed
            }
        }

        var title: String {
            switch self {
            case .idle: return "● Not connected"
            case .checking: return "● Checking connection…"
            case .connected: return "● Connected to Grafana"
            case .failed: return "● Connection failed"
            }
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var snapshot: PollSnapshot?
    private var error: Error?
    private var isLoading = false
    private var connectionState: ConnectionState = .idle

    var refreshRequested: (() -> Void)?
    var signInRequested: (() -> Void)?
    var settingsRequested: (() -> Void)?

    override init() {
        super.init()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon(count: 0, hasUnseen: false)
    }

    func setLoading(_ value: Bool) {
        isLoading = value
        if value {
            switch connectionState {
            case .connected:
                // Keep showing the last known-good connection during routine
                // background refreshes. A failure will replace it explicitly.
                break
            case .idle, .checking, .failed:
                connectionState = .checking
            }
        }
        rebuild()
    }

    func update(snapshot: PollSnapshot) {
        self.snapshot = snapshot
        self.error = nil
        self.isLoading = false
        self.connectionState = .connected(snapshot.fetchedAt)
        rebuild()
    }

    func show(error: Error) {
        self.error = error
        self.isLoading = false
        self.connectionState = .failed(error.localizedDescription)
        rebuild()
    }

    func menuWillOpen(_ menu: NSMenu) { rebuild() }

    private func rebuild() {
        menu.removeAllItems()
        let config = Config.shared
        let alerts = snapshot?.alerts ?? []
        let visible = alerts.filter { !config.mutedAlertIDs.contains($0.id) && $0.state != .normal }
        let firing = visible.filter { $0.state == .firing }
        let unseenFiring = firing.filter { !config.seenAlertIDs.contains($0.id) }
        updateIcon(count: firing.count, hasUnseen: !unseenFiring.isEmpty)

        addConnectionStatus()
        menu.addItem(.separator())

        if Config.shared.grafanaURL == nil {
            addDisabled("Set a Grafana URL to begin")
        } else if alerts.isEmpty, error == nil, !isLoading {
            addDisabled(snapshot == nil ? "Sign in, then refresh" : "No active alerts")
        }

        for state in [AlertState.firing, .pending, .error] {
            let items = visible.filter { $0.state == state }
            guard !items.isEmpty else { continue }
            addHeader("\(state.rawValue) (\(items.count))")
            for alert in items { menu.addItem(alertItem(alert, muted: false)) }
        }

        let muted = alerts.filter { config.mutedAlertIDs.contains($0.id) }
        if !muted.isEmpty {
            addHeader("Muted (\(muted.count))")
            for alert in muted { menu.addItem(alertItem(alert, muted: true)) }
        }

        if let error {
            menu.addItem(.separator())
            let item = NSMenuItem(title: "⚠︎ \(error.localizedDescription)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        if let fetchedAt = snapshot?.fetchedAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            addDisabled("Last checked \(formatter.string(from: fetchedAt))")
        }
        menu.addItem(actionItem(isLoading ? "Refreshing…" : "Refresh Now", #selector(refresh)))
        menu.addItem(actionItem("Sign in to Grafana…", #selector(signIn)))
        menu.addItem(actionItem("Settings…", #selector(settings), key: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Alarm Radar", #selector(quit), key: "q"))
    }

    private func alertItem(_ alert: MonitoredAlert, muted: Bool) -> NSMenuItem {
        let seen = Config.shared.seenAlertIDs.contains(alert.id)
        let prefix = seen ? "" : "● "
        let severity = alert.severity.map { "[\($0)] " } ?? ""
        let item = NSMenuItem(title: "\(prefix)\(severity)\(alert.ruleName)", action: #selector(openAlert(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = alert.id
        item.toolTip = [alert.summary, alert.detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")

        let submenu = NSMenu()
        let open = NSMenuItem(title: "Open in Grafana", action: #selector(openAlert(_:)), keyEquivalent: "")
        open.target = self
        open.representedObject = alert.id
        submenu.addItem(open)
        let mute = NSMenuItem(title: muted ? "Unmute" : "Mute", action: #selector(toggleMute(_:)), keyEquivalent: "")
        mute.target = self
        mute.representedObject = alert.id
        submenu.addItem(mute)
        item.submenu = submenu
        return item
    }

    private func updateIcon(count: Int, hasUnseen: Bool) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: hasUnseen ? "exclamationmark.triangle.fill" : "exclamationmark.triangle", accessibilityDescription: "Alarm Radar")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.title = count > 0 ? " \(count)" : ""
        // Let macOS choose the correct template color for light/dark menu bars.
        // Applying semantic colors here can make status-item images disappear
        // against translucent or accessibility menu-bar backgrounds.
        button.contentTintColor = nil
        switch connectionState {
        case .idle: button.toolTip = "Alarm Radar — not connected"
        case .checking: button.toolTip = "Alarm Radar — checking Grafana connection"
        case .connected: button.toolTip = "Alarm Radar — connected to Grafana"
        case let .failed(message): button.toolTip = "Alarm Radar — \(message)"
        }
    }

    private func addConnectionStatus() {
        let item = NSMenuItem(title: connectionState.title, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(
            string: connectionState.title,
            attributes: [.foregroundColor: connectionState.color, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)]
        )
        item.toolTip = {
            switch connectionState {
            case let .failed(message): return message
            case let .connected(date): return "Last successful response: \(date.formatted(date: .omitted, time: .standard))"
            default: return nil
            }
        }()
        menu.addItem(item)
    }

    private func addHeader(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addDisabled(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refresh() { refreshRequested?() }
    @objc private func signIn() { signInRequested?() }
    @objc private func settings() { settingsRequested?() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openAlert(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let alert = snapshot?.alerts.first(where: { $0.id == id }) else { return }
        Config.shared.markSeen(id)
        let fallback = Config.shared.grafanaURL?.appending(path: "alerting/list")
        if let url = alert.generatorURL ?? fallback { NSWorkspace.shared.open(url) }
        rebuild()
    }

    @objc private func toggleMute(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Config.shared.toggleMuted(id)
        rebuild()
    }
}
