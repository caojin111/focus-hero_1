import SwiftUI

struct FontSampleView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("自定义字体 - 标题1")
                        .font(.custom("Fibberish", size: 28))
                    
                    Text("自定义字体 - 标题2")
                        .font(.custom("Fibberish", size: 24))
                    
                    Text("自定义字体 - 标题3")
                        .font(.custom("Fibberish", size: 20))
                    
                    Text("自定义字体 - 正文")
                        .font(.custom("Fibberish", size: 16))
                    
                    Text("自定义字体 - 小文本")
                        .font(.custom("Fibberish", size: 14))
                }
                
                Divider()
                
                Group {
                    Text("系统字体 - 标题1")
                        .font(.largeTitle)
                    
                    Text("系统字体 - 标题2")
                        .font(.title)
                    
                    Text("系统字体 - 标题3")
                        .font(.title2)
                    
                    Text("系统字体 - 正文")
                        .font(.body)
                    
                    Text("系统字体 - 小文本")
                        .font(.caption)
                }
            }
            .padding()
        }
    }
}

#Preview {
    FontSampleView()
} 