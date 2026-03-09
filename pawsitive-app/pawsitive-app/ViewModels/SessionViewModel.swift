//
//  SessionViewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Combine
import Foundation
import Supabase
import SwiftUI

class SessionViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isRoleLoaded: Bool = false
    @Published var role: UserRole = .citizen
    @Published var currentUser: User?

    private var authStateSubscription: Task<Void, Never>?

    init() {
        // Start listening to auth state changes when initialized
        startListeningToAuthState()
    }

    deinit {
        authStateSubscription?.cancel()
    }

    private func startListeningToAuthState() {
        authStateSubscription = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                print("🔐 [SessionViewModel] Auth state changed: \\(event)")

                DispatchQueue.main.async {
                    self.currentUser = session?.user
                    self.isLoggedIn = session != nil

                    if let user = session?.user, let accessToken = session?.accessToken {
                        print(
                            "✅ [SessionViewModel] User logged in: \\(user.email ?? \"unknown\"), ID: \\(user.id)"
                        )

                        // Store user ID and access token in keychain
                        do {
                            try KeychainManager.shared.save(key: .userID, value: user.id.uuidString)
                            try KeychainManager.shared.save(key: .accessToken, value: accessToken)
                            print("💾 [SessionViewModel] Saved user ID and token to keychain")
                        } catch {
                            print("❌ [SessionViewModel] Failed to save to keychain: \(error)")
                        }

                        // Fast-track role from keychain if it exists to avoid UI flashing
                        if let cachedRoleString = KeychainManager.shared.getString(key: .userRole),
                            let cachedRole = UserRole(rawValue: cachedRoleString)
                        {
                            self.role = cachedRole
                            self.isRoleLoaded = true
                            print(
                                "💾 [SessionViewModel] Loaded user role from keychain: \(cachedRoleString)"
                            )
                        }

                        // Fetch the user's role from the database
                        self.fetchUserRole(userId: user.id)
                    } else {
                        print("🚪 [SessionViewModel] User logged out")
                        self.isRoleLoaded = false
                        self.clearKeychainData()
                    }
                }
            }
        }
    }

    private func fetchUserRole(userId: UUID) {
        Task {
            do {
                print("📡 [SessionViewModel] Fetching user role for ID: \\(userId)")

                struct UserProfile: Decodable {
                    let role: UserRole
                }

                let profile: UserProfile =
                    try await supabase
                    .from("users")
                    .select("role")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value

                DispatchQueue.main.async {
                    self.role = profile.role
                    self.isRoleLoaded = true
                    print("👤 [SessionViewModel] User role set to: \(profile.role.rawValue)")

                    // Store role in keychain
                    do {
                        try KeychainManager.shared.save(
                            key: .userRole, value: profile.role.rawValue)
                        print("💾 [SessionViewModel] Saved user role to keychain")
                    } catch {
                        print("❌ [SessionViewModel] Failed to save role to keychain: \\(error)")
                    }
                }
            } catch {
                print("❌ [SessionViewModel] Error fetching user role: \\(error)")
            }
        }
    }

    private func clearKeychainData() {
        do {
            try KeychainManager.shared.delete(key: .userID)
            try KeychainManager.shared.delete(key: .accessToken)
            try KeychainManager.shared.delete(key: .userRole)
            print("🧹 [SessionViewModel] Cleared keychain data")
        } catch {
            print("⚠️ [SessionViewModel] Error clearing keychain: \\(error)")
        }
    }

    func logout() {
        Task {
            do {
                print("🚪 [SessionViewModel] Logging out...")
                try await supabase.auth.signOut()
                DispatchQueue.main.async {
                    self.clearKeychainData()
                }
            } catch {
                print("❌ [SessionViewModel] Error signing out: \\(error)")
            }
        }
    }
}
