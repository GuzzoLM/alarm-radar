import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = GrafanaSession()
    private lazy var client = GrafanaWebClient(session: session)
    private lazy var poller = PollCoordinator(client: client)
    private let menuManager = MenuManager()
    private lazy var settingsController = SettingsWindowController(
        onSave: { [weak self] in self?.configurationChanged() },
        onSignIn: { [weak self] in self?.showLogin() },
        onTest: { [weak self] completion in self?.testConnection(completion: completion) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuManager.refreshRequested = { [weak self] in
            Task { @MainActor in await self?.poller.refresh() }
        }
        menuManager.signInRequested = { [weak self] in self?.showLogin() }
        menuManager.settingsRequested = { [weak self] in self?.settingsController.show() }

        poller.didStart = { [weak self] in self?.menuManager.setLoading(true) }
        poller.didUpdate = { [weak self] snapshot in self?.menuManager.update(snapshot: snapshot) }
        poller.didFail = { [weak self] error in
            self?.menuManager.show(error: error)
            if case RadarError.notAuthenticated = error { self?.showLogin() }
        }
        session.authenticationChanged = { [weak self] authenticated in
            if authenticated {
                self?.session.hideLogin()
                Task { @MainActor in await self?.poller.refresh() }
            }
        }

        if let url = Config.shared.grafanaURL {
            session.configure(baseURL: url)
            poller.start()
        } else {
            settingsController.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller.stop()
    }

    private func configurationChanged() {
        guard let url = Config.shared.grafanaURL else {
            menuManager.show(error: RadarError.notConfigured)
            return
        }
        session.configure(baseURL: url)
        poller.restart()
    }

    private func showLogin() {
        guard let url = Config.shared.grafanaURL else {
            settingsController.show()
            return
        }
        session.showLogin(baseURL: url)
    }

    private func testConnection(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = Config.shared.grafanaURL else {
            completion(.failure(RadarError.notConfigured))
            return
        }
        session.configure(baseURL: url)
        Task {
            do {
                try await client.testConnection()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
