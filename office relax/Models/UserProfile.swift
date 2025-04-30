//
//  UserProfile.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import Foundation

struct UserProfile: Codable {
    var age: Int                     // 年龄
    var gender: String               // 性别
    var jobType: String              // 工作类型
    var exerciseLevel: String        // 运动强度
    var catName: String              // 猫咪名称
    var coins: Int                   // 金币数量
    var onboardingCompleted: Bool    // 是否完成引导
    var recommendedWorkDuration: Int // 推荐工作时长（分钟）
    var recommendedRelaxDuration: Int // 推荐休息时长（分钟）
    var focusCount: Int              // 专注次数计数
    
    init(age: Int = 25, 
         gender: String = "男", 
         jobType: String = "程序开发者", 
         exerciseLevel: String = "偶尔运动", 
         catName: String = "懒猫", 
         coins: Int = 0,
         onboardingCompleted: Bool = false) {
        
        self.age = age
        self.gender = gender
        self.jobType = jobType
        self.exerciseLevel = exerciseLevel
        self.catName = catName
        self.coins = coins
        self.onboardingCompleted = onboardingCompleted
        self.focusCount = 0
        
        // 计算推荐工作和休息时长
        self.recommendedWorkDuration = UserProfile.calculateWorkDuration(
            age: age, 
            gender: gender, 
            jobType: jobType, 
            exerciseLevel: exerciseLevel
        )
        
        self.recommendedRelaxDuration = UserProfile.calculateRelaxDuration(
            workDuration: self.recommendedWorkDuration
        )
    }
    
    // 计算推荐工作时长
    static func calculateWorkDuration(age: Int, gender: String, jobType: String, exerciseLevel: String) -> Int {
        // 基础时长（分钟）
        var baseDuration = 25
        
        // 根据年龄调整
        if age < 25 {
            baseDuration -= 2
        } else if age > 35 {
            baseDuration += 3
        }
        
        // 根据工作类型调整
        switch jobType {
        case "程序开发者":
            baseDuration += 5
        case "艺术设计工作者":
            baseDuration += 3
        case "体力劳动者":
            baseDuration -= 5
        default:
            break
        }
        
        // 根据运动强度调整
        switch exerciseLevel {
        case "从不运动":
            baseDuration -= 3
        case "经常运动":
            baseDuration += 2
        default:
            break
        }
        
        // 确保时长在合理范围内
        return min(max(baseDuration, 1), 45)
    }
    
    // 计算推荐休息时长
    static func calculateRelaxDuration(workDuration: Int) -> Int {
        // 休息时间为工作时间的1/5到1/4
        return workDuration / 4
    }
} 