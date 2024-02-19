import Foundation

public class SecureStorage {
    public static let authKey = "AUTH_TOKEN"
    
    private let serviceName: String
    
    public init() {
        serviceName = Bundle.main.bundleIdentifier ?? "SandboxSecureStorage"
    }
    
    public func save<D: Codable>(key: String, value: D) {
        guard let data = try? JSONEncoder().encode(value) else {
            print(KeychainError.jsonSerializationError)
            return
        }
        
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecAttrService as String: serviceName,
                                    kSecValueData as String: data]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem { // duplicate detected (code -25299). User did not log out before logging again
                print("duplicate detected, updating data instead")
                return update(key: key, value: value)
            } else {
                print(KeychainError.unhandledError(status: status))
                return
            }
        }
        if key == SecureStorage.authKey {
            print("send SecureStorage.save.DidSetAuthToken")
            NotificationCenter.default.post(name: .DidSetAuthToken, object: nil)
        }
        print("SecureStorage.save success")
    }
    
    private func update<D: Codable>(key: String, value: D) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: serviceName,
                                    kSecAttrAccount as String: key]
        
        guard let data = try? JSONEncoder().encode(value) else {
            print(KeychainError.jsonSerializationError)
            return
        }
        
        let attributes: [String: Any] = [kSecAttrAccount as String: key,
                                         kSecAttrService as String: serviceName,
                                         kSecValueData as String: data]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status != errSecItemNotFound else {
            print(KeychainError.noToken)
            return
        }
        guard status == errSecSuccess else {
            print(KeychainError.unhandledError(status: status))
            return
        }
        
        if key == SecureStorage.authKey {
            print("send SecureStorage.update.DidSetAuthToken")
            //TODO: passer le token dans la notif pour pouvoir le récupérer directement
            NotificationCenter.default.post(name: .DidSetAuthToken, object: nil)
        }
        print("SecureStorage.update success")
    }
    
    //TODO: implémenter un fonction spécifique pour AuthToken pour ne pas à avoir le problème de type et pour y mettre les notifs
    public func get<D: Codable>(key: String) -> D? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecAttrService as String: serviceName,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: false,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            print(KeychainError.noToken)
            return nil
        }
        guard status == errSecSuccess else {
            print(KeychainError.unhandledError(status: status))
            return nil
        }
        
        guard let existingItem = item as? Data else {
            print(KeychainError.unexpectedTokenData)
            return nil
        }
        
        do {
            let decode: D = try JSONDecoder().decode(D.self, from: existingItem)
            print("SecureStorage.get success")
            return decode
        } catch {
            print(KeychainError.jsonDeserializationError(error: error))
            return nil
        }
    }
    
    public func take<D: Codable>(key: String) -> D? {
        let value: D? = self.get(key: key)
        clear(key: key)
        print("SecureStorage.take success")
        return value
    }
    
    public func clear(key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: serviceName,
                                    kSecAttrAccount as String: key]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print(KeychainError.unhandledError(status: status))
            return
        }
        if key == SecureStorage.authKey {
            NotificationCenter.default.post(name: .DidClearAuthToken, object: nil)
        }
        print("SecureStorage.clear success")
    }
}

enum KeychainError: Error {
    case noToken
    case unexpectedTokenData
    case jsonSerializationError
    case jsonDeserializationError(error: Error)
    case unhandledError(status: OSStatus)
}

extension NSNotification.Name {
    static let DidSetAuthToken = Notification.Name("DidSetAuthToken")
    static let DidClearAuthToken = Notification.Name("DidClearAuthToken")
}
