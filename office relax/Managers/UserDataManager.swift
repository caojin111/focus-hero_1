//
//  UserDataManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import Foundation
import Combine

class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @Published var userProfile: UserProfile
    
    private init() {
        // 尝试从UserDefaults加载用户数据
        if let userData = UserDefaults.standard.data(forKey: "userProfile"),
           let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            userProfile = decodedProfile
        } else {
            // 如果没有存储的数据，创建默认配置文件
            userProfile = UserProfile()
        }
    }
    
    // 保存用户数据到UserDefaults
    func saveUserProfile() {
        if let encodedData = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(encodedData, forKey: "userProfile")
        }
    }
    
    // 更新用户基本信息
    func updateUserInfo(age: Int, gender: String, jobType: String, exerciseLevel: String, catName: String) {
        userProfile.age = age
        userProfile.gender = gender
        userProfile.jobType = jobType
        userProfile.exerciseLevel = exerciseLevel
        userProfile.catName = catName
        
        // 更新推荐时长
        userProfile.recommendedWorkDuration = UserProfile.calculateWorkDuration(
            age: age,
            gender: gender,
            jobType: jobType,
            exerciseLevel: exerciseLevel
        )
        
        userProfile.recommendedRelaxDuration = UserProfile.calculateRelaxDuration(
            workDuration: userProfile.recommendedWorkDuration
        )
        
        // 完成引导
        userProfile.onboardingCompleted = true
        
        // 保存更新后的数据
        saveUserProfile()
    }
    
    // 更新用户设置：专注时间、休息时间和英雄名称
    func updateUserSettings(focusTime: Int, breakTime: Int, heroName: String) {
        // 直接设置工作和休息时长
        userProfile.recommendedWorkDuration = focusTime
        userProfile.recommendedRelaxDuration = breakTime
        
        // 更新英雄名称（原猫咪名称）
        userProfile.catName = heroName
        
        // 完成引导
        userProfile.onboardingCompleted = true
        
        // 保存更新后的数据
        saveUserProfile()
    }
    
    // 添加金币
    func addCoins(_ amount: Int) {
        userProfile.coins += amount
        saveUserProfile()
    }
    
    // 扣除金币
    func deductCoins(_ amount: Int) -> Bool {
        if userProfile.coins >= amount {
            userProfile.coins -= amount
            saveUserProfile()
            return true
        }
        return false
    }
    
    // 获取工作时长（分钟）
    func getWorkDuration() -> Int {
        return userProfile.recommendedWorkDuration
    }
    
    // 获取休息时长（分钟）
    func getRelaxDuration() -> Int {
        return userProfile.recommendedRelaxDuration
    }
    
    // 更新工作时长
    func updateWorkDuration(_ duration: Int) {
        userProfile.recommendedWorkDuration = duration
        saveUserProfile()
    }
    
    // 更新休息时长
    func updateRelaxDuration(_ duration: Int) {
        userProfile.recommendedRelaxDuration = duration
        saveUserProfile()
    }
} 