//
//  Login_ViewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Combine
import Foundation
import Supabase

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isPasswordVisible = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showAlert = false

    func login(session: SessionViewModel) async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signIn(email: email, password: password)
            // On success, SessionViewModel will automatically pick it up
            HapticManager.shared.trigger(.success)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showAlert = true
            HapticManager.shared.trigger(.error)
            print("Login Error: \(error)")
        }
    }
}
