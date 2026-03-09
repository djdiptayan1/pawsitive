import SwiftUI

struct ButtonMain: View {
    let title: String
    var isLoading: Bool = false
    var color: Color = AppConfig.Colors.accent
    var textColor: Color = AppConfig.Colors.textPrimary
    var font: Font = AppConfig.Fonts.cuteDino(size: 28)
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            action()
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(textColor)
                } else {
                    Text(title)
                        .font(font)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
//            .frame(height: 60)
            .background(color)
            .cornerRadius(AppConfig.UI.buttonCornerRadius)
            .shadow(color: color.opacity(0.5), radius: 0, x: 0, y: 6)
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack {
        ButtonMain(title: "Login") {}
        ButtonMain(title: "Loading", isLoading: true) {}
    }
    .padding()
}
