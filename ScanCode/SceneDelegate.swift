import SwiftUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let scanViewController = ScanViewController()
    private lazy var navigationController = UINavigationController(rootViewController: scanViewController)
    private var intelligenceGlowOverlayController: UIHostingController<AppleIntelligenceGlowOverlay>?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        navigationController.setNavigationBarHidden(true, animated: false)
        window.rootViewController = navigationController
        installIntelligenceGlowOverlay()
        window.makeKeyAndVisible()

        self.window = window

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

    func installIntelligenceGlowOverlay() {
        let overlayController = UIHostingController(rootView: AppleIntelligenceGlowOverlay())
        overlayController.view.backgroundColor = .clear
        overlayController.view.isOpaque = false
        overlayController.view.isUserInteractionEnabled = false
        overlayController.view.translatesAutoresizingMaskIntoConstraints = false

        navigationController.addChild(overlayController)
        navigationController.view.addSubview(overlayController.view)
        NSLayoutConstraint.activate([
            overlayController.view.leadingAnchor.constraint(equalTo: navigationController.view.leadingAnchor),
            overlayController.view.trailingAnchor.constraint(equalTo: navigationController.view.trailingAnchor),
            overlayController.view.topAnchor.constraint(equalTo: navigationController.view.topAnchor),
            overlayController.view.bottomAnchor.constraint(equalTo: navigationController.view.bottomAnchor)
        ])
        overlayController.didMove(toParent: navigationController)

        intelligenceGlowOverlayController = overlayController
    }
}
