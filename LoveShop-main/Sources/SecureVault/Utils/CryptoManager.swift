import Foundation
import CryptoKit
import Security

/// Шифрует/расшифровывает данные, хранящиеся в хранилище приложения
/// (фото, метаданные, заметки), при помощи AES-256-GCM. Ключ генерируется
/// один раз и хранится в Keychain — благодаря этому файлы на диске
/// остаются нечитаемым бинарным мусором даже при прямом доступе
/// к файловой системе приложения (например, через сторонние
/// файловые менеджеры), а не только скрыты из системного UI.
enum CryptoManager {
    private static let keychainService = "com.securevault.encryption"
    private static let keychainAccount = "vaultMasterKey"

    private static let symmetricKey: SymmetricKey = {
        if let existing = loadKeyFromKeychain() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        saveKeyToKeychain(newKey)
        return newKey
    }()

    static func encrypt(_ data: Data) -> Data? {
        guard let sealed = try? AES.GCM.seal(data, using: symmetricKey) else { return nil }
        return sealed.combined
    }

    static func decrypt(_ data: Data) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: data) else { return nil }
        return try? AES.GCM.open(box, using: symmetricKey)
    }

    private static func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private static func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
