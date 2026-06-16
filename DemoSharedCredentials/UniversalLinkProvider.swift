import UIKit
import AuthenticationServices
import Reach5

/// Provider de démonstration qui gère un retour en **lien universel** (https) au lieu d'un
/// custom scheme — cas non supporté par `ReachFive.webviewLogin()` (SDK ≤ 10.x), car celui-ci
/// crée une `ASWebAuthenticationSession(url:callbackURLScheme:)` qui ne matche que les custom schemes.
///
/// On réimplémente donc l'appel à `ASWebAuthenticationSession` nous-mêmes, en s'appuyant sur
/// les briques publiques du SDK : `Pkce.generate()`, `buildAuthorizeURL(...)`, `authWithCode(code:pkce:)`.
///
/// Deux stratégies, choisies automatiquement :
///  - **iOS 17.4+** : `ASWebAuthenticationSession.Callback.https` matche nativement le lien
///    universel. Tout est self-contained, aucune plomberie SceneDelegate nécessaire.
///  - **iOS < 17.4** : on garde une référence à la session. C'est le `SceneDelegate` qui nous
///    transmet le lien universel via `scene(_:continue:)`. On annule alors la session
///    (`session.cancel()`), on extrait le `code` de l'URL et on termine via `authWithCode`.
@MainActor
final class UniversalLinkProvider: NSObject {

    // MARK: - À renseigner selon ta config Reach5

    /// Nom du provider tel que configuré côté Reach5 (paramètre `provider` de /authorize).
    private let providerName: String
    /// Host du lien universel qui clôt le flux et porte le `code`.
    /// Doit être déclaré dans Associated Domains (`applinks:` pour < 17.4, `webcredentials:` pour 17.4+).
    /// Déjà le cas pour les domaines Reach5 dans DemoSharedCredentials.entitlements.
    private let callbackHost: String
    /// Path attendu du lien universel (utilisé uniquement par le callback `.https` natif, iOS 17.4+).
    private let callbackPath: String

    // MARK: - Dépendances

    private let reachfive: ReachFive
    private let presentationContextProvider: ASWebAuthenticationPresentationContextProviding

    // MARK: - État de la session en cours

    private var session: ASWebAuthenticationSession?
    private var pkce: Pkce?
    private var completion: ((Result<AuthToken, ReachFiveError>) -> Void)?

    /// Référence faible vers le login en cours, pour que le `SceneDelegate` puisse lui router
    /// le lien universel (chemin iOS < 17.4 uniquement).
    private(set) static weak var pending: UniversalLinkProvider?

    init(reachfive: ReachFive,
         providerName: String,
         callbackHost: String,
         callbackPath: String = "/",
         presentationContextProvider: ASWebAuthenticationPresentationContextProviding) {
        self.reachfive = reachfive
        self.providerName = providerName
        self.callbackHost = callbackHost
        self.callbackPath = callbackPath
        self.presentationContextProvider = presentationContextProvider
    }

    // MARK: - Login

    func login(scope: [String]? = nil,
               origin: String = "UniversalLinkProvider",
               completion: @escaping (Result<AuthToken, ReachFiveError>) -> Void) {
        let pkce = Pkce.generate()
        self.pkce = pkce
        self.completion = completion

        let url = reachfive.buildAuthorizeURL(
            pkce: pkce,
            scope: scope,
            origin: origin,
            provider: providerName)

        let session: ASWebAuthenticationSession
        if #available(iOS 17.4, *) {
            // Chemin natif : la session matche directement le callback https → completionHandler classique.
            session = ASWebAuthenticationSession(
                url: url,
                callback: .https(host: callbackHost, path: callbackPath)) { [weak self] callbackURL, error in
                    self?.resolve(callbackURL: callbackURL, error: error)
                }
        } else {
            // Repli : la session ne matchera jamais (callback https ≠ custom scheme). Le completionHandler
            // ne servira qu'à capter l'annulation utilisateur ; le succès arrivera via le SceneDelegate.
            UniversalLinkProvider.pending = self
            session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: reachfive.sdkConfig.baseScheme) { [weak self] callbackURL, error in
                    self?.resolve(callbackURL: callbackURL, error: error)
                }
        }

        session.presentationContextProvider = presentationContextProvider
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        session.start()
    }

    // MARK: - Réception du lien universel (chemin iOS < 17.4, appelé par le SceneDelegate)

    /// Renvoie `true` si ce login a pris en charge le lien universel.
    func handleUniversalLink(_ url: URL) -> Bool {
        guard completion != nil, url.host == callbackHost else { return false }

        // On résout AVANT d'annuler : `resolve` met `completion` à nil, donc le callback
        // d'annulation de la session deviendra un no-op et n'écrasera pas notre succès.
        let runningSession = session
        resolve(callbackURL: url, error: nil)
        runningSession?.cancel() // ferme la web sheet restée ouverte
        return true
    }

    // MARK: - Résolution (point unique, garde-fou contre la double exécution)

    private func resolve(callbackURL: URL?, error: Error?) {
        guard let completion = self.completion else { return }
        self.completion = nil
        self.session = nil
        UniversalLinkProvider.pending = nil

        if let error {
            // _code == 1 → ASWebAuthenticationSessionError.canceledLogin
            let r5: ReachFiveError = (error as NSError).code == 1
                ? .AuthCanceled
                : .TechnicalError(reason: error.localizedDescription)
            completion(.failure(r5))
            return
        }

        guard let callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true)?
                  .queryItems?.first(where: { $0.name == "code" })?.value,
              let pkce = self.pkce else {
            completion(.failure(.TechnicalError(
                reason: "Pas de code d'autorisation dans \(callbackURL?.absoluteString ?? "nil")")))
            return
        }

        // Échange code ↔ token : exactement ce que faisait webviewLogin() en interne.
        Task {
            do {
                let token = try await reachfive.authWithCode(code: code, pkce: pkce)
                completion(.success(token))
            } catch let e as ReachFiveError {
                completion(.failure(e))
            } catch {
                completion(.failure(.TechnicalError(reason: error.localizedDescription)))
            }
        }
    }
}
