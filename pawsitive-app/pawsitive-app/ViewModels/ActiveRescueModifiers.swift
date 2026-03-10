//
//  ActiveRescueModifiers.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import Foundation
import SwiftUI
import UIKit

struct RescueBadgeModifier: ViewModifier {
    var color: Color
    var isSolid: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(isSolid ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSolid ? color : color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct PrimaryActionModifier: ViewModifier {
    var backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .font(AppConfig.Fonts.bodyBold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(AppConfig.UI.buttonCornerRadius)
            .shadow(color: backgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct InfoRowView: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = AppConfig.Colors.accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
                Text(value)
                    .font(AppConfig.Fonts.body)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Corner Radius Helper

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - View Extensions

extension View {
    func rescueBadge(color: Color, isSolid: Bool = false) -> some View {
        self.modifier(RescueBadgeModifier(color: color, isSolid: isSolid))
    }

    func primaryActionStyle(color: Color) -> some View {
        self.modifier(PrimaryActionModifier(backgroundColor: color))
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

