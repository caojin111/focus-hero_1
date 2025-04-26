//
//  SettingsView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var userDataManager = UserDataManager.shared
    @StateObject private var audioManager = AudioManager.shared
    
    @AppStorage("settings_sound_enabled") private var soundEnabled = true
    @AppStorage("settings_sound_volume") private var soundVolume = 0.7
    
    @AppStorage("settings_vibration_enabled") private var vibrationEnabled = true
    
    @State private var workDuration: Double = 0
    @State private var relaxDuration: Double = 0
    
    var body: some View {
        NavigationView {
            Form {
                // 时间设置部分
                Section(header: Text("时间设置")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("工作时长")
                            Spacer()
                            Text("\(Int(workDuration)) 分钟")
                                .foregroundColor(.gray)
                        }
                        Slider(value: $workDuration, in: 15...60, step: 1)
                            .onChange(of: workDuration) { newValue in
                                userDataManager.updateWorkDuration(Int(newValue))
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("休息时长")
                            Spacer()
                            Text("\(Int(relaxDuration)) 分钟")
                                .foregroundColor(.gray)
                        }
                        Slider(value: $relaxDuration, in: 5...30, step: 1)
                            .onChange(of: relaxDuration) { newValue in
                                userDataManager.updateRelaxDuration(Int(newValue))
                            }
                    }
                }
                
                Section(header: Text("背景音乐")) {
                    Toggle("启用背景音乐", isOn: $audioManager.isMusicEnabled)
                    
                    if audioManager.isMusicEnabled {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                            Slider(value: $audioManager.musicVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("音效")) {
                    Toggle("启用音效", isOn: $soundEnabled)
                    
                    if soundEnabled {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                            Slider(value: $soundVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("震动")) {
                    Toggle("启用震动", isOn: $vibrationEnabled)
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("LazyCat")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("设置")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #endif
            }
            .onAppear {
                // 加载初始值
                workDuration = Double(userDataManager.getWorkDuration())
                relaxDuration = Double(userDataManager.getRelaxDuration())
            }
        }
    }
}

#Preview {
    SettingsView()
} 