//
//  AudioManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    // 背景音乐播放器
    private var workModePlayer: AVAudioPlayer?
    private var relaxModePlayer: AVAudioPlayer?
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    
    // 音量设置 (0.0 - 1.0)
    @Published var musicVolume: Float = 0.5 {
        didSet {
            workModePlayer?.volume = musicVolume
            relaxModePlayer?.volume = musicVolume
        }
    }
    
    // 是否启用背景音乐
    @Published var isMusicEnabled: Bool = true {
        didSet {
            if isMusicEnabled {
                // 恢复之前的音乐播放
                if isWorkMode {
                    playWorkMusic()
                } else {
                    playRelaxMusic()
                }
            } else {
                // 停止所有音乐
                stopAllMusic()
            }
        }
    }
    
    // 当前模式
    private var isWorkMode: Bool = true
    
    private init() {
        setupAudioSession()
        prepareAudioPlayers()
    }
    
    // 设置音频会话
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("无法设置音频会话: \(error.localizedDescription)")
        }
    }
    
    // 准备音频播放器
    private func prepareAudioPlayers() {
        // 加载工作模式音乐
        if let workMusicURL = Bundle.main.url(forResource: "work_music", withExtension: "mp3") {
            do {
                workModePlayer = try AVAudioPlayer(contentsOf: workMusicURL)
                workModePlayer?.numberOfLoops = -1 // 无限循环
                workModePlayer?.volume = musicVolume
                workModePlayer?.prepareToPlay()
            } catch {
                print("无法加载工作模式音乐: \(error.localizedDescription)")
            }
        } else {
            print("未找到工作模式音乐文件")
        }
        
        // 加载休息模式音乐
        if let relaxMusicURL = Bundle.main.url(forResource: "relax_music", withExtension: "mp3") {
            do {
                relaxModePlayer = try AVAudioPlayer(contentsOf: relaxMusicURL)
                relaxModePlayer?.numberOfLoops = -1 // 无限循环
                relaxModePlayer?.volume = musicVolume
                relaxModePlayer?.prepareToPlay()
            } catch {
                print("无法加载休息模式音乐: \(error.localizedDescription)")
            }
        } else {
            print("未找到休息模式音乐文件")
        }
    }
    
    // 播放工作模式音乐
    func playWorkMusic() {
        guard isMusicEnabled else { return }
        
        // 渐弱停止休息音乐
        fadeOutAndStop(player: relaxModePlayer) {
            // 渐强开始工作音乐
            self.fadeInAndPlay(player: self.workModePlayer)
        }
        
        isWorkMode = true
    }
    
    // 播放休息模式音乐
    func playRelaxMusic() {
        guard isMusicEnabled else { return }
        
        // 渐弱停止工作音乐
        fadeOutAndStop(player: workModePlayer) {
            // 渐强开始休息音乐
            self.fadeInAndPlay(player: self.relaxModePlayer)
        }
        
        isWorkMode = false
    }
    
    // 停止所有音乐
    func stopAllMusic() {
        fadeOutAndStop(player: workModePlayer)
        fadeOutAndStop(player: relaxModePlayer)
    }
    
    // 暂停所有音乐
    func pauseAllMusic() {
        workModePlayer?.pause()
        relaxModePlayer?.pause()
    }
    
    // 暂停所有音效
    func pauseAllSounds() {
        for (_, player) in soundPlayers {
            player.pause()
        }
    }
    
    // 恢复工作模式音乐
    func resumeWorkMusic() {
        guard isMusicEnabled else { return }
        workModePlayer?.play()
    }
    
    // 恢复休息模式音乐
    func resumeRelaxMusic() {
        guard isMusicEnabled else { return }
        relaxModePlayer?.play()
    }
    
    // 恢复所有音效
    func resumeAllSounds() {
        for (_, player) in soundPlayers {
            player.play()
        }
    }
    
    // 渐弱停止音乐
    private func fadeOutAndStop(player: AVAudioPlayer?, completion: (() -> Void)? = nil) {
        guard let player = player, player.isPlaying else {
            completion?()
            return
        }
        
        let initialVolume = player.volume
        let fadeTime = 1.0 // 淡出时间（秒）
        let fadeSteps = 20 // 淡出步骤数
        let volumeStep = initialVolume / Float(fadeSteps)
        let timeStep = fadeTime / Double(fadeSteps)
        
        var currentStep = 0
        
        let fadeTimer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { timer in
            currentStep += 1
            
            if currentStep >= fadeSteps {
                player.stop()
                player.volume = initialVolume
                timer.invalidate()
                completion?()
            } else {
                player.volume = initialVolume - (volumeStep * Float(currentStep))
            }
        }
        
        RunLoop.main.add(fadeTimer, forMode: .common)
    }
    
    // 渐强开始音乐
    private func fadeInAndPlay(player: AVAudioPlayer?) {
        guard let player = player else { return }
        
        player.volume = 0.0
        player.play()
        
        let targetVolume = musicVolume
        let fadeTime = 1.0 // 淡入时间（秒）
        let fadeSteps = 20 // 淡入步骤数
        let volumeStep = targetVolume / Float(fadeSteps)
        let timeStep = fadeTime / Double(fadeSteps)
        
        var currentStep = 0
        
        let fadeTimer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { timer in
            currentStep += 1
            
            if currentStep >= fadeSteps {
                player.volume = targetVolume
                timer.invalidate()
            } else {
                player.volume = volumeStep * Float(currentStep)
            }
        }
        
        RunLoop.main.add(fadeTimer, forMode: .common)
    }
    
    // 播放音效
    func playSound(_ name: String) {
        // 如果已经有播放器在播放这个音效，先停止它
        if let existingPlayer = soundPlayers[name] {
            existingPlayer.stop()
            soundPlayers.removeValue(forKey: name)
        }
        
        // 加载音效文件
        guard let soundURL = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("未找到音效文件: \(name)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = 0.8 // 设置音效音量
            player.prepareToPlay()
            player.play()
            
            // 保存播放器引用
            soundPlayers[name] = player
            
            // 播放完成后清理
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) {
                self.soundPlayers.removeValue(forKey: name)
            }
        } catch {
            print("播放音效时出错: \(error.localizedDescription)")
        }
    }
} 