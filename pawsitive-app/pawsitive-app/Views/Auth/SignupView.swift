//
//  Signup.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import SwiftUI

struct SignupView: View {
    @StateObject private var viewModel = SignupViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var avatarIndex = Int.random(in: 1...9)

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.Colors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        //                        headerView

                        VStack(spacing: 20) {
                            if viewModel.currentStep == .account {
                                accountStepView
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .trailing).combined(
                                                with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity))
                                    )
                            } else {
                                profileStepView
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .trailing).combined(
                                                with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity))
                                    )
                            }
                        }
                        .padding(.top, 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8),
                            value: viewModel.currentStep)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Create your Account")
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("Signup Failed"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Pawsitive")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                Image(systemName: "pawprint.fill")
                    .foregroundColor(AppConfig.Colors.accent)
                    .font(.system(size: 24))
            }
            .padding(.top, 20)

            if viewModel.currentStep == .account {
                Text("Create Your Account")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .padding(.top, 20)
            } else {
                VStack(spacing: 4) {
                    Text("Create Your Profile")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppConfig.Colors.textPrimary)
                    Text("Step 2 of 2")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(AppConfig.Colors.textPrimary)
                }
                .padding(.top, 20)
            }
        }
    }

    private var accountStepView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                RoleButton(
                    title: "Citizen", color: AppConfig.Colors.accent,
                    isSelected: viewModel.role == .citizen
                ) {
                    viewModel.role = .citizen
                }
                RoleButton(
                    title: "Rescuer", color: AppConfig.Colors.softAccent,
                    isSelected: viewModel.role == .rescuer
                ) {
                    viewModel.role = .rescuer
                }
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 16) {
                Text("Your Details")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)

                VStack(spacing: 16) {
                    AestheticInput(
                        icon: "envelope.fill",
                        title: "Email",
                        placeholder: "Your Email",
                        text: $viewModel.email,
                        isPasswordVisible: .constant(true)
                    )
                    AestheticInput(
                        icon: "lock.fill",
                        title: "Password",
                        placeholder: "Create Password",
                        text: $viewModel.password,
                        isSecure: true,
                        showToggle: true,
                        isPasswordVisible: $isPasswordVisible
                    )
                    AestheticInput(
                        icon: "lock.fill",
                        title: "Confirm Password",
                        placeholder: "Confirm Password",
                        text: $viewModel.confirmPassword,
                        isSecure: true,
                        showToggle: true,
                        isPasswordVisible: $isConfirmPasswordVisible
                    )
                }
            }

            VStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(AppConfig.Colors.textPrimary)
                    Button("Log In") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .underline()
                }
                .padding(.top, 8)

                ButtonMain(title: "Next", isLoading: false) {
                    viewModel.handleNext()
                }
            }
        }
    }

    private var profileStepView: some View {
        VStack(spacing: 24) {
            // Avatar Selector
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppConfig.Colors.card)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle().stroke(AppConfig.Colors.stroke, lineWidth: 3)
                        )

                    // Display Random Dog Avatar
                    Image("Group \(avatarIndex)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }

                Button(action: {
                    HapticManager.shared.trigger(.selection)
                    avatarIndex = Int.random(in: 1...9)
                }) {
                    HStack {
                        Image(systemName: "die.face.5")
                        Text("Shuffle")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppConfig.Colors.accent)
                    .clipShape(Capsule())
                    //                    .overlay(Capsule().stroke(AppConfig.Colors.stroke, lineWidth: 1.5))
                }
            }
            .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 16) {
                Text("Your Details")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textPrimary)

                VStack(spacing: 16) {
                    AestheticInput(
                        icon: "person.fill",
                        title: "Full Name",
                        placeholder: "Full Name",
                        text: $viewModel.fullName,
                        isPasswordVisible: .constant(true)
                    )
                    AestheticInput(
                        icon: "phone.fill",
                        title: "Phone Number",
                        placeholder: "+1 234 567 8901",
                        text: $viewModel.phoneNumber,
                        isPasswordVisible: .constant(true)
                    )
                }
            }

            VStack(spacing: 16) {
                ButtonMain(title: "Complete Setup", isLoading: viewModel.isLoading) {
                    viewModel.completeSetup()
                }

                Text(
                    "By completing setup, you agree to our [Terms and Conditions](https://example.com)."
                )
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(AppConfig.Colors.textPrimary)
                .tint(AppConfig.Colors.textPrimary)
                .multilineTextAlignment(.center)
            }
            .padding(.top, 10)
        }
    }
}

struct RoleButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            action()
        }) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppConfig.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: AppConfig.UI.buttonCornerRadius))
                .shadow(
                    color: AppConfig.Colors.stroke.opacity(isSelected ? 0.2 : 0.05), radius: 8,
                    x: 0,
                    y: 4
                )
                .opacity(isSelected ? 1.0 : 0.6)
                .scaleEffect(isSelected ? 1.0 : 0.95)
                .animation(.spring(), value: isSelected)
        }
    }
}

#Preview {
    SignupView()
}
