import SwiftUI

public struct PageDots: View {
    let count: Int
    let activeIndex: Int
    let activeColor: Color

    public init(count: Int, activeIndex: Int, activeColor: Color) {
        self.count = count
        self.activeIndex = activeIndex
        self.activeColor = activeColor
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(i == activeIndex ? activeColor : DesignTokens.Surface.dotInactive)
                    .overlay(Rectangle().stroke(.black, lineWidth: 1))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
