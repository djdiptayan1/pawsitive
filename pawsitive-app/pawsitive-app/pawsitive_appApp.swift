//
//  pawsitive_appApp.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import SwiftUI

@main
struct PawsitiveApp: App {

    @StateObject private var session = SessionViewModel()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}
