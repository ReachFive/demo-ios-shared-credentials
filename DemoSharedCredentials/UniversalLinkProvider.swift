import UIKit
import AuthenticationServices
import Reach5

/// Provider qui gère un retour en **lien universel** (https) au lieu d'un custom scheme — cas non
/// supporté par `DefaultProvider`/`webviewLogin()` du SDK (≤ 10.x), qui crée une
/// `ASWebAuthenticationSession(url:callbackURLScheme:)` ne matchant que les custom schemes.
///
/// En conformant au protocole `Provider`, ce provider s'intègre exactement comme les autres :
///  - il est instancié par le SDK via `UniversalLinkProviderCreator` (au lieu du `DefaultProvider`
///    générique), dès lors que son `name` correspond au provider renvoyé par la config serveur ;
///  - il est récupérable par `reachfive.getProvider(name:)` / `getProviders()` ;
///  - `login(scope:origin:viewController:)` (et donc la variante `Future` de Reach5Future) marche
///    de la même façon ;
///  - il reçoit le lien universel via `application(_:continue:restorationHandler:)`, routé par le SDK.
///
/// Deux stratégies, choisies automatiquement :
///  - **iOS 17.4+** : `ASWebAuthenticationSession.Callback.https` matche nativement le lien universel
///    → `completionHandler` classique, aucune plomberie SceneDelegate nécessaire.
///  - **iOS < 17.4** : la session ne matche jamais le https ; le lien universel arrive par
///    `application(_:continue:)`. On annule alors la session, on extrait le `code`, et on termine
///    via `authWithCode`.
public final class UniversalLinkProvider: NSObject, Provider {

    public let name: String

    private let reachfive: ReachFive
    /// Host du lien universel qui clôt le flux et porte le `code` (déduit de `providerConfig.universalLink`).
    private let callbackHost: String
    /// Path du lien universel (utilisé par le callback `.https` natif, iOS 17.4+).
    private let callbackPath: String

    // État du login en cours — toujours manipulé sur le main thread.
    private var session: ASWebAuthenticationSession?
    private var pkce: Pkce?
    private var continuation: CheckedContinuation<AuthToken, Error>?

    public init(reachfive: ReachFive,
                providerConfig: ProviderConfig,
                callbackHost: String? = nil,
                callbackPath: String? = nil) {
        self.reachfive = reachfive
        self.name = providerConfig.provider

        // Le SDK connaît déjà le lien universel côté config serveur : on le réutilise.
        let link = providerConfig.universalLink.flatMap { URL(string: $0) }
        self.callbackHost = callbackHost ?? link?.host ?? ""
        let path = callbackPath ?? link?.path ?? "/"
        self.callbackPath = path.isEmpty ? "/" : path
    }

    // MARK: - Provider.login

    public func login(scope: [String]?, origin: String, viewController: UIViewController?) async throws -> AuthToken {
        guard let presentationContextProvider = viewController as? ASWebAuthenticationPresentationContextProviding else {
            throw ReachFiveError.TechnicalError(reason: "No presenting viewController")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthToken, Error>) in
            DispatchQueue.main.async {
                self.continuation = continuation

                let pkce = Pkce.generate()
                self.pkce = pkce

                let url = self.reachfive.buildAuthorizeURL(pkce: pkce, scope: scope, origin: origin, provider: self.name)

                let session: ASWebAuthenticationSession
                if #available(iOS 17.4, *) {
                    // Chemin natif : la session matche directement le callback https.
                    session = ASWebAuthenticationSession(
                        url: url,
                        callback: .https(host: self.callbackHost, path: self.callbackPath)) { [weak self] callbackURL, error in
                            self?.handleCallback(url: callbackURL, error: error)
                        }
                } else {
                    // Repli : le completionHandler ne servira qu'à capter l'annulation utilisateur ;
                    // le succès arrivera par application(_:continue:).
                    session = ASWebAuthenticationSession(
                        url: url,
                        callbackURLScheme: self.reachfive.sdkConfig.baseScheme) { [weak self] callbackURL, error in
                            self?.handleCallback(url: callbackURL, error: error)
                        }
                }

                session.presentationContextProvider = presentationContextProvider
                session.prefersEphemeralWebBrowserSession = false
                self.session = session
                session.start()
            }
        }
    }

    // MARK: - Provider : routage du lien universel (chemin iOS < 17.4)

    public func application(_ application: UIApplication,
                            continue userActivity: NSUserActivity,
                            restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard continuation != nil,
              userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              url.host == callbackHost else {
            return false
        }
        handleCallback(url: url, error: nil)
        return true
    }

    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        false
    }

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {}

    public func logout() {}

    // MARK: - Résolution (point unique, garde-fou contre la double exécution)

    /// Appelé soit par le `completionHandler` de la session (chemin natif / annulation),
    /// soit par `application(_:continue:)` (chemin lien universel < 17.4). Toujours sur le main thread.
    private func handleCallback(url: URL?, error: Error?) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        let runningSession = self.session
        self.session = nil
        runningSession?.cancel() // ferme la web sheet restée ouverte (no-op si déjà terminée)

        if let error {
            // _code == 1 → ASWebAuthenticationSessionError.canceledLogin
            let r5: ReachFiveError = (error as NSError).code == 1
                ? .AuthCanceled
                : .TechnicalError(reason: error.localizedDescription)
            continuation.resume(throwing: r5)
            return
        }

        guard let url,
              let code = URLComponents(url: url, resolvingAgainstBaseURL: true)?
                  .queryItems?.first(where: { $0.name == "code" })?.value,
              let pkce = self.pkce else {
            continuation.resume(throwing: ReachFiveError.TechnicalError(
                reason: "Pas de code d'autorisation dans \(url?.absoluteString ?? "nil")"))
            return
        }

        // Échange code ↔ token : exactement ce que faisait webviewLogin() en interne.
        Task {
            do {
                let token = try await reachfive.authWithCode(code: code, pkce: pkce)
                continuation.resume(returning: token)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Enregistre `UniversalLinkProvider` auprès du SDK. Le `name` doit correspondre au provider renvoyé
/// par la config serveur Reach5 ; sinon le SDK retombe sur le `DefaultProvider` générique.
public final class UniversalLinkProviderCreator: ProviderCreator {
    public let name: String
    public let variant: String?

    /// Résolu paresseusement : l'instance `ReachFive` n'existe pas encore quand le creator est
    /// construit (il est passé à l'init de `ReachFive`). `create(...)` n'est appelé que plus tard,
    /// pendant `initialize()`, quand l'instance est disponible.
    private let reachfiveResolver: () -> ReachFive

    public init(name: String, variant: String? = nil, reachfive: @escaping @autoclosure () -> ReachFive) {
        self.name = name
        self.variant = variant
        self.reachfiveResolver = reachfive
    }

    public func create(sdkConfig: SdkConfig,
                       providerConfig: ProviderConfig,
                       reachFiveApi: ReachFiveApi,
                       clientConfigResponse: ClientConfigResponse) -> Provider {
        UniversalLinkProvider(reachfive: reachfiveResolver(), providerConfig: providerConfig)
    }
}
