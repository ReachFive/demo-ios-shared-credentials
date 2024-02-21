import Foundation
import IdentitySdkCore

public class SecureStorage: Storage {
    public static let authKey = "AUTH_TOKEN"
    private static let refKey = "SHARED_REFS"
    
    private let serviceName: String
    private let group: String
    private let bundleId: String
    
    private let sendNotif: Bool
    
    public init(group: String? = nil) {
        bundleId = Bundle.main.bundleIdentifier!
        serviceName = group ?? bundleId
        sendNotif = group == nil
        
        self.group = group ?? (Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String) + bundleId
        print("SecureStorage.init(group: \(group ?? "")) serviceName:\(serviceName) accessGroup: \(self.group)")
    }
    
    public func setToken(_ token: AuthToken) -> ()? {
        set(token, forKey: SecureStorage.authKey).flatMap { _ in
                let refs: Set<String>? = get(key: SecureStorage.refKey)
                if var refs {
                    if refs.insert(bundleId).inserted {
                        return set(refs, forKey: SecureStorage.refKey)
                    } else {
                        return ()
                    }
                } else {
                    let ref: Set = [bundleId]
                    return set(ref, forKey: SecureStorage.refKey)
                }
            }
            .flatMap { r in
                print("send .DidSetAuthToken")
                if sendNotif {
                    NotificationCenter.default.post(name: .DidSetAuthToken, object: nil, userInfo: ["token": token])
                }
                return r
            }
    }
    
    public func clearToken() -> ()? {
        guard var refs: Set<String> = get(key: SecureStorage.refKey) else {
            print("trying to clear a token without references")
            return nil
        }
        guard let _ = refs.remove(bundleId) else {
            print("trying to clear a token not present in the references")
            return nil
        }
        return set(refs, forKey: SecureStorage.refKey).flatMap { _ in
            if !refs.isEmpty {
                return ()
            }
            return remove(key: SecureStorage.authKey).flatMap { _ in
                if sendNotif {
                    NotificationCenter.default.post(name: .DidClearAuthToken, object: nil)
                }
                return ()
            }
        }
    }
    
    public func set<D: Codable>(_ value: D, forKey key: String) -> ()? {
        guard let data = try? JSONEncoder().encode(value) else {
            print(KeychainError.jsonSerializationError)
            return nil
        }
        
        print("save data: \(data)")
        
        let attributes = [kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key,
                          kSecAttrService: serviceName,
                          kSecAttrAccessGroup: group,
                          kSecAttrSynchronizable: true,
                          kSecValueData: data] as [String: Any]
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem { // duplicate detected (code -25299). User did not log out before logging again
                print("duplicate detected, updating data instead")
                return update(value, forKey: key)
            } else {
                print(KeychainError.unhandledError(status: status))
                return nil
            }
        }
        return ()
    }
    
    public func save<D: Codable>(key: String, value: D) {
        if let _ = set(value, forKey: key) {
            print("SecureStorage.save success")
        }
    }
    
    private func update<D: Codable>(_ value: D, forKey key: String) -> ()? {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrService: serviceName,
                     kSecAttrAccessGroup: group,
                     kSecAttrSynchronizable: true,
                     kSecAttrAccount: key] as [String: Any]
        
        guard let data = try? JSONEncoder().encode(value) else {
            print(KeychainError.jsonSerializationError)
            return nil
        }
        
        let attributes = [kSecAttrAccount: key,
                          kSecAttrService: serviceName,
                          kSecAttrAccessGroup: group,
                          kSecAttrSynchronizable: true,
                          kSecValueData: data] as [String: Any]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status != errSecItemNotFound else {
            print(KeychainError.noToken)
            return nil
        }
        
        guard status == errSecSuccess else {
            print(KeychainError.unhandledError(status: status))
            return nil
        }
        
        return ()
    }
    
    public func get<D: Codable>(key: String) -> D? {
        let attributes = [kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key,
                          kSecAttrService: serviceName,
                          kSecAttrAccessGroup: group,
                          kSecAttrSynchronizable: true,
                          kSecMatchLimit: kSecMatchLimitOne,
                          kSecReturnAttributes: false,
                          kSecReturnData: true] as [String: Any]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &item)
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
    
    public func remove(key: String) -> ()? {
        let attributes: [String: Any] = [kSecClass: kSecClassGenericPassword,
                                         kSecAttrService: serviceName,
                                         kSecAttrAccessGroup: group,
                                         kSecAttrSynchronizable: true,
                                         kSecAttrAccount: key] as [String: Any]
        
        let status = SecItemDelete(attributes as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print(KeychainError.unhandledError(status: status))
            return nil
        }
        print("SecureStorage.clear success")
        return ()
    }
    
    public func clear(key: String) {
        remove(key: key)
    }
    
}

public enum KeychainError: Error {
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
