import Foundation

struct GiftPackage: Codable, Identifiable {
    var id: String
    var name: String
    var price: Double
    var priceString: String
    var description: String
    var includedItems: [String] // 包含的物品ID列表
    
    // 默认初始化方法
    init(id: String, name: String, price: Double, priceString: String, description: String, includedItems: [String]) {
        self.id = id
        self.name = name
        self.price = price
        self.priceString = priceString
        self.description = description
        self.includedItems = includedItems
    }
    
    // 静态方法，创建启动礼包
    static func createStarterPackage() -> GiftPackage {
        return GiftPackage(
            id: "starter_package_0.99",
            name: "初学者礼包",
            price: 0.99,
            priceString: "$0.99",
            description: "包含两个特效道具，提升您的工作体验",
            includedItems: ["effect_3", "effect_6"]
        )
    }
} 