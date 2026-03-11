//
//  tabBar.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import SwiftUI

struct MainTabBar: View {

    @EnvironmentObject var session: SessionViewModel
    var tabs: [AppTab] {
        switch session.role {
        case .citizen:
            return [
                AppTab(
                    title: "SOS",
                    systemImage: "exclamationmark.triangle.fill",
                    view: AnyView(SOSView())
                ),

                AppTab(
                    title: "Map",
                    systemImage: "map.fill",
                    view: AnyView(CitizenMapView())
                ),

                // AppTab(
                //     title: "Profile",
                //     systemImage: "person.crop.circle",
                //     view: AnyView(CitizenProfileView())
                // ),
            ]

        case .rescuer:
            return [
                AppTab(
                    title: "Map",
                    systemImage: "map.fill",
                    view: AnyView(RescuerMapView())
                ),

                // AppTab(
                //     title: "Jobs",
                //     systemImage: "briefcase.fill",
                //     view: AnyView(JobsView())
                // ),

                AppTab(
                    title: "Active",
                    systemImage: "cross.case.fill",
                    view: AnyView(ActiveRescueView())
                ),

                AppTab(
                    title: "Profile",
                    systemImage: "person.crop.circle",
                    view: AnyView(RescuerProfileViewWrapper())
                ),
            ]
        }
    }

    var body: some View {
        TabView {
            ForEach(tabs) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    tab.view
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(AppConfig.Colors.accent)
    }
}

#Preview {
    MainTabBar()
        .environmentObject(
            {
                let session = SessionViewModel()
                session.role = .citizen
                session.isLoggedIn = true
                return session
            }())
}
