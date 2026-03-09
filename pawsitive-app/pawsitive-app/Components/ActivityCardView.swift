//
//  ActivityCardView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import SwiftUI

struct ActivityCardView: View {
    let activity: RecentActivityModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Thumbnail
            ZStack {
                if let photoUrlString = activity.photoUrl, let photoUrl = URL(string: photoUrlString) {
                    AsyncImage(url: photoUrl) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            AppConfig.Colors.accent.opacity(0.1)
                                .overlay(
                                    Image(systemName: "pawprint.fill")
                                        .foregroundColor(AppConfig.Colors.accent)
                                        .font(.title2)
                                )
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                } else {
                    AppConfig.Colors.accent.opacity(0.1)
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .foregroundColor(AppConfig.Colors.accent)
                                .font(.title2)
                        )
                }
            }
            .frame(width: 85, height: 85)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                // Badges Row
                HStack(spacing: 6) {
                    Text((activity.status ?? "Reported").uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppConfig.Colors.accent.opacity(0.15))
                        .foregroundColor(AppConfig.Colors.accent)
                        .clipShape(Capsule())
                    
                    Spacer()
                }
                
                Text(activity.title ?? "Animal Rescue Request")
                    .font(AppConfig.Fonts.bodyBold)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .lineLimit(1)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .frame(width: 14)
                        Text(activity.locationName ?? "Unknown Location")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .frame(width: 14)
                        Text(Self.formatDate(activity.createdAt))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppConfig.Colors.card)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: AppConfig.UI.cardShadowRadius, x: 0, y: AppConfig.UI.cardShadowOffsetY)
    }
    
    private static func formatDate(_ dateStr: String?) -> String {
        guard let dateStr else { return "Recently" }
        let istZone = TimeZone(identifier: "Asia/Kolkata")!
        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy, h:mm a"
        display.timeZone = istZone
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(abbreviation: "UTC")!
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss.SSSSSS", "yyyy-MM-dd HH:mm:ss"] {
            parser.dateFormat = fmt
            if let date = parser.date(from: dateStr) { return display.string(from: date) }
        }
        return "Recently"
    }
}
