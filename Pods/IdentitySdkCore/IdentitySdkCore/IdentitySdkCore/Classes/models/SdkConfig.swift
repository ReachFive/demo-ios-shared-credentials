import Foundation

public class SdkConfig {
    public let domain: String
    public let clientId: String
    
    /// Alias for the `redirectUri`
    public let scheme: String
    
    ///The scheme of the form `reachfive-clientId`
    public let baseScheme: String
    /// The redirect URI of the form `reachfive-clientId://callback`
    public let redirectUri: String
    
    public init(domain: String, clientId: String, scheme: String) {
        self.domain = domain
        self.clientId = clientId
        self.scheme = scheme
        redirectUri = scheme
        baseScheme = "reachfive-\(clientId)"
    }
    
    public init(domain: String, clientId: String) {
        self.domain = domain
        self.clientId = clientId
        baseScheme = "reachfive-\(clientId)"
        redirectUri = "\(baseScheme)://callback"
        scheme = redirectUri
    }
}
