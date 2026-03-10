import SwiftUI

struct FirstAidStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

struct FirstAidGuideView: View {
    let severity: UrgencySeverity
    let onDone: () -> Void

    // MARK: - Dynamic Theming
    var themeColor: Color {
        switch severity {
        case .severe: return AppConfig.Colors.alert
        case .moderate: return AppConfig.Colors.warning
        case .minor: return AppConfig.Colors.success // Using success/mint for a calming minor theme
        }
    }
    
    var severityLabel: String {
        switch severity {
        case .severe: return "Severe Injury Guide"
        case .moderate: return "Moderate Injury Guide"
        case .minor: return "Safety & Care Guide"
        }
    }

    var steps: [FirstAidStep] {
        switch severity {
        case .severe:
            return [
                FirstAidStep(icon: "🚫", title: "Do not move the animal", detail: "Pain can cause panic bites. Keep a safe distance and maintain a calm voice."),
                FirstAidStep(icon: "🩸", title: "Apply gentle pressure", detail: "Use a clean cloth to reduce bleeding. Do not remove any embedded objects."),
                FirstAidStep(icon: "🌡️", title: "Prevent shock", detail: "Cover them with a cloth or jacket if safe to do so. Keep the area quiet and warm."),
                FirstAidStep(icon: "📸", title: "Document quickly", detail: "Capture clear photos for the rescuer and vet, including the immediate surroundings."),
            ]
        case .moderate:
            return [
                FirstAidStep(icon: "🧤", title: "Approach slowly", detail: "Let the animal see you. Avoid sudden touches, especially around injured areas."),
                FirstAidStep(icon: "💧", title: "Offer water nearby", detail: "Place water close to them, but do not force feeding or drinking."),
                FirstAidStep(icon: "🧣", title: "Stabilize movement", detail: "Use a towel or cloth to keep movement minimal until the rescuer arrives."),
                FirstAidStep(icon: "🗺️", title: "Keep location clear", detail: "Stay visible and guide the responding rescuer to the exact spot."),
            ]
        case .minor:
            return [
                FirstAidStep(icon: "🍽️", title: "Offer food and water", detail: "Use small portions to gain their trust and keep the animal nearby."),
                FirstAidStep(icon: "🛡️", title: "Create a safe zone", detail: "Keep other people and traffic away while help is on the way."),
                FirstAidStep(icon: "🐾", title: "Avoid chasing", detail: "Move calmly. A sudden pursuit can push a scared animal into danger."),
                FirstAidStep(icon: "📍", title: "Share landmarks", detail: "Note nearby shops or street signs so the rescuer can find you instantly."),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Section
            VStack(alignment: .leading, spacing: 16) {
                // Top Indicator Pill
                HStack(spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(severityLabel.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(themeColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeColor.opacity(0.15))
                .clipShape(Capsule())
                .padding(.top, 24)
                
                Text("What to do right now")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Help is already on the way. Please follow these steps to protect the animal and yourself during these critical minutes.")
                    .font(AppConfig.Fonts.body)
                    .foregroundColor(AppConfig.Colors.textSecondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, AppConfig.UI.screenPadding)
            .padding(.bottom, 24)
            
            // MARK: - Steps List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepCard(step: step, index: index + 1)
                    }
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.bottom, 30)
                .padding(.top, 4)
            }
            
            // MARK: - Action Button
            VStack {
                Button(action: onDone) {
                    HStack {
                        Text("I understand, close guide")
                    }
                    // Reusing your custom modifier here
                    .primaryActionStyle(color: AppConfig.Colors.accent)
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.bottom, 16)
                .padding(.top, 12)
                .background(
                    // Soft gradient fade at the bottom to transition into the button
                    LinearGradient(
                        stops: [
                            .init(color: AppConfig.Colors.background.opacity(0.0), location: 0),
                            .init(color: AppConfig.Colors.background, location: 0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .background(AppConfig.Colors.background.ignoresSafeArea())
    }
    
    // MARK: - Reusable Step Card
    @ViewBuilder
    private func stepCard(step: FirstAidStep, index: Int) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 54, height: 54)
                
                Text(step.icon)
                    .font(.system(size: 26))
                
                // Small step number indicator
                ZStack {
                    Circle()
                        .fill(AppConfig.Colors.card)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(themeColor)
                        .frame(width: 16, height: 16)
                    Text("\(index)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .offset(x: 18, y: -18)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                
                Text(step.detail)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppConfig.Colors.card)
        .cornerRadius(20)
        // Soft, modern drop shadow
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        // Subtle border to define the card against the background
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppConfig.Colors.stroke.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    // Assuming UrgencySeverity is an enum in your project
    FirstAidGuideView(severity: .severe, onDone: {})
}
