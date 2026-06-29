import UIKit
import AuthenticationServices
import Reach5

/// Provider de démonstration pour le cas — non géré par `DefaultProvider`/`webviewLogin()` du SDK
/// 10.x — où le provider termine son flux par un **lien universel** (https) au lieu du custom scheme
/// attendu.
///
/// ## Le problème
/// `webviewLogin()` crée une `ASWebAuthenticationSession(url:callbackURLScheme:)` qui ne reconnaît
/// que les **custom schemes**. Dans la topologie réelle, c'est une **app tierce** (p. ex. la banque
/// qui réalise la vérification d'identité) qui rouvre l'app hôte via le lien universel porteur du
/// `code`. Ce lien est livré par le système à `application(_:continue:)` pendant que la session web
/// est encore ouverte — le `completionHandler` de la session, lui, ne se déclenche jamais pour lui.
///
/// > Le callback `.https` d'`ASWebAuthenticationSession` (iOS 17.4+) **ne résout pas** ce cas : il
/// > n'intercepte que les redirections naviguées *à l'intérieur* de la web view de la session, pas un
/// > lien universel ouvert depuis une autre app. On ne l'utilise donc pas — une seule stratégie suffit.
///
/// ## La stratégie (unique)
/// 1. On présente la session web sur le custom scheme : elle ne sert qu'à afficher l'UI et à remonter
///    l'**annulation** utilisateur (son `completionHandler` ne verra jamais de succès).
/// 2. Le succès arrive hors-bande via `application(_:continue:)` : on en extrait le `code`, on annule
///    la session restée ouverte, puis on échange le code contre un token via `authWithCode` (PKCE).
///
/// En conformant au protocole `Provider`, ce provider s'intègre comme les autres :
///  - instancié par le SDK via `UniversalLinkProviderCreator` dès que son `name` correspond au
///    provider renvoyé par la config serveur (sinon le SDK retombe sur le `DefaultProvider`) ;
///  - récupérable via `reachfive.getProvider(name:)` / `getProviders()` ;
///  - `login(...)` (et la variante `Future` de Reach5Future) marche à l'identique.
///
/// ## Prérequis côté app hôte
///  - un Associated Domain `applinks:<host>` (+ apple-app-site-association servi par le domaine) ;
///  - le forward de `scene(_:continue:)` / `application(_:continue:)` vers
///    `reachfive.application(_:continue:…)`, qui route l'activité vers ce provider.
///
/// > Note : depuis la branche `feature/CA-6191_b_connect`, le SDK gère ce cas **nativement** dans
/// > `DefaultProvider` (en passant le lien universel comme `redirect_uri` pour `/authorize` ET
/// > `/token`). Ce fichier reste un exemple pédagogique pour les intégrateurs encore sur le SDK 10
/// > publié ; il n'utilise que des primitives publiques (`Pkce`, `buildAuthorizeURL`, `authWithCode`).
public final class UniversalLinkProvider: NSObject, Provider {

    public let name: String

    private let reachfive: ReachFive

    /// Lien universel qui clôt le flux et porte le `code`, déduit de `providerConfig.universalLink`
    /// (config serveur). Un lien entrant n'est accepté que si son host correspond et que son path le
    /// préfixe — même filtre que le `DefaultProvider` natif. `nil` ⇒ le provider n'intercepte rien.
    private let universalLink: URL?

    // État du login en cours — toujours manipulé sur le main thread.
    private var session: ASWebAuthenticationSession?
    private var pkce: Pkce?
    private var continuation: CheckedContinuation<AuthToken, Error>?

    public init(reachfive: ReachFive, providerConfig: ProviderConfig, universalLink: URL? = nil) {
        self.reachfive = reachfive
        self.name = providerConfig.provider
        self.universalLink = universalLink ?? providerConfig.universalLink.flatMap { URL(string: $0) }
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

                // Session sur le custom scheme : elle héberge l'UI web et ne remonte que l'annulation.
                // Le succès, lui, revient par lien universel via application(_:continue:).
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: self.reachfive.sdkConfig.baseScheme) { [weak self] callbackURL, error in
                        self?.handleCallback(url: callbackURL, error: error)
                    }
                session.presentationContextProvider = presentationContextProvider
                session.prefersEphemeralWebBrowserSession = false
                self.session = session
                session.start()
            }
        }
    }

    // MARK: - Provider : réception du lien universel (chemin de succès)

    public func application(_ application: UIApplication,
                            continue userActivity: NSUserActivity,
                            restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard continuation != nil,
              let universalLink,
              userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              url.host == universalLink.host,
              url.path.hasPrefix(universalLink.path) else {
            return false
        }
        handleCallback(url: url, error: nil)
        return true
    }

    // Hooks de cycle de vie requis par le protocole — sans objet pour ce provider.
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool { false }
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    public func applicationDidBecomeActive(_ application: UIApplication) {}
    public func logout() {}

    // MARK: - Résolution (point unique, garde-fou contre la double exécution)

    /// Appelé soit par `application(_:continue:)` (succès, lien universel), soit par le
    /// `completionHandler` de la session (annulation / erreur). Toujours sur le main thread.
    private func handleCallback(url: URL?, error: Error?) {
        guard let continuation = self.continuation else { return }
        // Neutralisé avant cancel() : la session peut rappeler son completionHandler de façon
        // ré-entrante (annulation), mais la garde ci-dessus l'ignorera alors.
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
