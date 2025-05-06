import Foundation
import Security

class KeychainHelper {
    
    static let standard = KeychainHelper()
    private init() {}
    
    // MARK: - Save 方法
    
    func save(_ data: Data, service: String, account: String) {
        
        // 创建查询字典
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        // 添加数据到keychain
        let status = SecItemAdd(query, nil)
        
        // 如果已存在，则更新
        if status == errSecDuplicateItem {
            let updateQuery = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as CFDictionary
            
            let updatedAttributes = [
                kSecValueData: data
            ] as CFDictionary
            
            SecItemUpdate(updateQuery, updatedAttributes)
        }
        
        print("Keychain保存状态: \(status == errSecSuccess || status == errSecDuplicateItem ? "成功" : "失败(\(status))")")
    }
    
    // MARK: - 泛型Save方法
    
    func save<T: Codable>(_ item: T, service: String, account: String) {
        do {
            let data = try JSONEncoder().encode(item)
            save(data, service: service, account: account)
        } catch {
            print("编码失败 - \(error)")
        }
    }
    
    // MARK: - 读取方法
    
    func read(service: String, account: String) -> Data? {
        
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("Keychain读取失败: \(status)")
            return nil
        }
    }
    
    // MARK: - 泛型读取方法
    
    func read<T: Codable>(service: String, account: String, type: T.Type) -> T? {
        guard let data = read(service: service, account: account) else {
            return nil
        }
        
        do {
            let item = try JSONDecoder().decode(type, from: data)
            return item
        } catch {
            print("解码失败 - \(error)")
            return nil
        }
    }
    
    // MARK: - 删除方法
    
    func delete(service: String, account: String) {
        
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        let status = SecItemDelete(query)
        print("Keychain删除状态: \(status == errSecSuccess ? "成功" : "失败(\(status))")")
    }
} 