import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let scanViewController = ScanViewController()
    private lazy var navigationController = UINavigationController(rootViewController: scanViewController)
    private var matrixRainOverlayView: MatrixRainOverlayView?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.view.backgroundColor = .black
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
        DispatchQueue.main.async { [weak self] in
            self?.installMatrixRainOverlay()
        }

        if let initialURL = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async { [weak self] in
                self?.handleDeepLink(initialURL)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }
}

private extension SceneDelegate {

    func handleDeepLink(_ url: URL) {
        guard let action = ScanAppAction(url: url) else { return }

        navigationController.popToRootViewController(animated: false)
        scanViewController.handleExternalAction(action)
    }

    func installMatrixRainOverlay() {
        let overlayView = MatrixRainOverlayView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false

        navigationController.view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: navigationController.view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: navigationController.view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: navigationController.view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: navigationController.view.bottomAnchor)
        ])

        matrixRainOverlayView = overlayView
    }
}
