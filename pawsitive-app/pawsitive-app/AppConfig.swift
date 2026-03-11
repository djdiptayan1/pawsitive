//
//  appConfig.swift
//  pawsitive
//
//  Created by Diptayan Jash on 9/03/26.
//

import Foundation
import SwiftUI

struct AppConfig {
    /// UI constants
    struct UI {
        static let cornerRadius: CGFloat = 24
        static let buttonCornerRadius: CGFloat = 30
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowOffsetY: CGFloat = 4
        static let padding: CGFloat = 16
        static let screenPadding: CGFloat = 24
        static let spacing: CGFloat = 12
    }

    struct Colors {
        static let background = Color("AppBackground")
        static let card = Color("CardBackground")
        static let textPrimary = Color("PrimaryText")
        static let textSecondary = Color("SecondaryText")

        // Brand Action Colors
        static let accent = Color("Accent")  // Sun Orange
        static let softAccent = Color("SoftAccent")  // Baby Pink

        // Status & Triage Colors
        static let alert = Color("Alert")  // Severe
        static let warning = Color("Warning")  // Moderate
        static let success = Color("Success")  // Resolved

        static let stroke = Color("Stroke")
    }

    /*
      | Name           | Light (Hex) | Dark (Hex)  | Role                     |
      | -------------- | ----------- | ----------- | ------------------------ |
      | AppBackground  | `#FFF2E0`   | `#1F1F1F`   | Cream vs Deep Cocoa |
      | CardBackground | `#FFFFFF`   | `#2D2D2D`   | Muted Charcoal for Dark  |
      | PrimaryText    | `#1F1F1F`   | `#FFF2E0`   | Inverted Charcoal/Cream |
      | SecondaryText  | `#5A6777`   | `#AEB8C2`   | Muted Gray               |
      | Accent         | `#FEB447`   | `#FEB447`   | Sun Orange         |
      | SoftAccent     | `#FBBABE`   | `#E2A4A7`   | Baby Pink vs Dusty Rose |
      | Alert (Severe) | `#FF4E50`   | `#FF9A9A`   | Sunset Red               |
      | Warning (Mod)  | `#FFAD60`   | `#FFAD60`   | Goldenrod                |
      | Success        | `#48D1CC`   | `#83C94B`   | Mint Green               |
      | Stroke         | `#1F1F1F`   | `#FFF2E0`   | Dark vs Cream borders    |
     */

    struct Fonts {
        // Use design: .rounded to mimic "Cute Dino" feel if custom font isn't loaded
        static let titleLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let titleMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 18, weight: .regular, design: .rounded)
        static let bodyBold = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let small = Font.system(size: 14, weight: .regular, design: .rounded)
        static let smallBold = Font.system(size: 14, weight: .bold, design: .rounded)

        // Custom Font Helper (Call this once you add CuteDino.ttf to your info.plist)
        static func cuteDino(size: CGFloat) -> Font {
            return Font.custom("Cute-Dino", size: size)
        }
    }

    struct ApiEndpoints {
        //        static let baseURL = "http://localhost:3000/api/"  //-> USE WHEN USING SIMULATOR
        static let baseURL = "http://172.20.10.2:3000/api/"  //-> USE WHEN USING REAL PHONE
        //        static let baseURL = "https://recap-v2.vercel.app/api/" // -> PRODUCTION
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}

// extension View {
//    func standardBackground() -> some View {
//        background(AppBackground())
//    }
// }
