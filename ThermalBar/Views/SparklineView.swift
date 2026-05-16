import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let maxVal = data.max() ?? 100
                let minVal = data.min() ?? 0
                let range = max(maxVal - minVal, 10.0) // At least 10 degrees range for scale
                
                let stepX = width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(value - minVal) / CGFloat(range) * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
        .frame(height: 20)
    }
}
