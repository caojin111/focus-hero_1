import Foundation

struct ShopItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let price: Int
    let imageName: String
    let type: ItemType
    var isPurchased: Bool = false
    var isEquipped: Bool = false
    
    enum ItemType: String, Codable, CaseIterable {
        case effect = "effect"      // 特效
        case sound = "sound"        // 音效
        case bgm = "bgm"           // 背景音乐
        case background = "background" // 背景图
        case premium = "premium"    // 付费道具
    }
    
    static func == (lhs: ShopItem, rhs: ShopItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// 商品数据加载
extension ShopItem {
    static func loadItemsFromJSON() -> [ShopItem] {
        guard let url = Bundle.main.url(forResource: "shop_items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ShopItem].self, from: data) else {
            return sampleItems
        }
        return items
    }
    
    // 预设商品（作为备用）
    static let sampleItems: [ShopItem] = [
        // 特效
        ShopItem(id: "effect_1", name: "火焰特效", description: "炫酷的火焰效果，让战斗更加激烈。", price: 100, imageName: "effect_fire", type: .effect),
        ShopItem(id: "effect_2", name: "闪电特效", description: "强大的闪电效果，增加战斗气势。", price: 150, imageName: "effect_lightning", type: .effect),
        
        // 音效
        ShopItem(id: "sound_1", name: "胜利音效", description: "战斗胜利时的欢呼声。", price: 80, imageName: "sound_victory", type: .sound),
        ShopItem(id: "sound_2", name: "打击音效", description: "有力的打击声效。", price: 80, imageName: "sound_hit", type: .sound),
        
        // BGM
        ShopItem(id: "bgm_1", name: "战斗BGM", description: "激昂的战斗背景音乐。", price: 200, imageName: "bgm_battle", type: .bgm),
        ShopItem(id: "bgm_2", name: "史诗BGM", description: "史诗级的战斗音乐。", price: 250, imageName: "bgm_epic", type: .bgm),
        
        // 背景图
        ShopItem(id: "bg_1", name: "城市夜景", description: "现代都市的夜晚背景。", price: 300, imageName: "bg_city_night", type: .background),
        ShopItem(id: "bg_2", name: "森林清晨", description: "宁静的森林清晨背景。", price: 300, imageName: "bg_forest", type: .background),
        
        // 付费道具
        ShopItem(id: "premium_1", name: "豪华礼包", description: "包含所有特效和音效的豪华礼包。", price: 1000, imageName: "premium_pack", type: .premium)
    ]
} 