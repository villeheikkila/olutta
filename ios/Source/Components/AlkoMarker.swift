import SwiftUI

struct AlkoMarker: View {
    var count: Int? = nil

    var body: some View {
        VStack(spacing: 2) {
            AlkoIcon()
                .foregroundStyle(Color(red: 0xE3 / 255, green: 0x1C / 255, blue: 0x18 / 255))
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)

            if let count {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
            }
        }
    }
}
