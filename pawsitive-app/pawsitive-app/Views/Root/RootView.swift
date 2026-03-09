//
//  RootView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var showSplash: Bool = true

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                if session.isLoggedIn {
                    if session.isRoleLoaded {
                        MainTabBar()
                    } else {
                        SplashScreenView()
                    }
                } else {
                    LoginView()
                }
            }
        }
    }
}

#Preview {
    let session = SessionViewModel()
    session.isLoggedIn = false
    return RootView()
        .environmentObject(session)
}
