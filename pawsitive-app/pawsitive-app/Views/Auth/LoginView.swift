import DotLottie
import Supabase
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionViewModel
    @StateObject private var viewModel = LoginViewModel()
    @State private var showSignupSheet = false

    var body: some View {
        ZStack {
            AppConfig.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                //                Image(systemName: "pawprint.fill")
                //                    .resizable()
                //                    .scaledToFit()
                //                    .frame(width: 80, height: 80)
                //                    .foregroundColor(AppConfig.Colors.accent)
                //                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                DotLottieAnimation(
                    fileName: "AnimalPaws",
                    config: AnimationConfig(
                        autoplay: true,
                        loop: true,
                        speed: 0.6,
                        //                        width: 140,
                        //                        height: 140,
                    )
                )
                .view()

                Text("Pawsitive")
                    .font(AppConfig.Fonts.cuteDino(size: 42))
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .padding(.bottom, 20)

                VStack(spacing: 20) {
                    AestheticInput(
                        icon: "envelope.fill",
                        title: "Email",
                        placeholder: "Enter email address",
                        text: $viewModel.email,
                        isPasswordVisible: .constant(true)
                    )

                    AestheticInput(
                        icon: "lock.fill",
                        title: "Password",
                        placeholder: "Enter password",
                        text: $viewModel.password,
                        isSecure: true,
                        showToggle: true,
                        isPasswordVisible: $viewModel.isPasswordVisible
                    )
                }
                .padding(.horizontal, 30)

                ButtonMain(title: "Login", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.login(session: session)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 16)

                Spacer()

                HStack(spacing: 4) {
                    Text("New here?")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textPrimary)

                    Button(action: {
                        showSignupSheet = true
                    }) {
                        Text("Sign up")
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.textPrimary)
                            .underline()
                    }

                    Text("to save lives!")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showSignupSheet) {
            SignupView()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Login Failed"),
                message: Text(viewModel.errorMessage ?? "Unknown Error"),
                dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    LoginView()
}
