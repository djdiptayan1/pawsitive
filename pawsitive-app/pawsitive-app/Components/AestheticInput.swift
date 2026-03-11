import SwiftUI

struct AestheticInput: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var showToggle: Bool = false
    @Binding var isPasswordVisible: Bool

    private var shouldShowSecure: Bool {
        return isSecure && !isPasswordVisible
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppConfig.Fonts.bodyBold)
                .foregroundColor(AppConfig.Colors.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppConfig.Colors.accent)
                Group {
                    if shouldShowSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(AppConfig.Fonts.body)
                .foregroundColor(AppConfig.Colors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)

                if showToggle {
                    Button(action: {
                        HapticManager.shared.trigger(.selection)
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppConfig.Colors.card)
            .cornerRadius(AppConfig.UI.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.UI.buttonCornerRadius)
                    .stroke(AppConfig.Colors.softAccent, lineWidth: 1.5)
            )
        }
    }
}
