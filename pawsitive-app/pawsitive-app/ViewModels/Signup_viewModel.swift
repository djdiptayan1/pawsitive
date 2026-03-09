//
//  Signup_viewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Combine
import Foundation
import Supabase
import SwiftUI

enum SignupStep {
    case account
    case profile
}

class SignupViewModel: ObservableObject {
    @Published var currentStep: SignupStep = .account
    @Published var role: UserRole = .citizen

    // Step 1
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    // Step 2
    @Published var fullName = ""
    @Published var phoneNumber = ""

    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showAlert = false

    func handleNext() {
        // Add your validation here
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep = .profile
        }
    }

    func completeSetup() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Save intended role to Keychain right before signup so that
                // the `SessionViewModel.authStateChanges` listener fetches it correctly.
                try? KeychainManager.shared.save(key: .userRole, value: role.rawValue)

                let authResponse = try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: [
                        "full_name": .string(fullName)
                        // Add other meta data here if necessary
                    ]
                )

                // If we need to set the role, we usually do it after signup.
                // Assuming the trigger creates the public.users row,
                // we can update it here.
                let userId = authResponse.user.id
                let updateData: [String: String] = [
                    "role": role.rawValue,
                    "phone": phoneNumber,
                ]

                _ =
                    try await supabase
                    .from("users")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()

                struct UserProfile: Decodable {
                    let role: String
                }
                let profile: UserProfile =
                    try await supabase
                    .from("users")
                    .select("role")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                try? KeychainManager.shared.save(key: .userRole, value: profile.role)

                DispatchQueue.main.async {
                    self.isLoading = false
                    // Success! SessionViewModel will pick up the auth state change
                    // and log the user in automatically.
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showAlert = true
                }
                print("Signup error: \(error)")
            }
        }
    }
}
