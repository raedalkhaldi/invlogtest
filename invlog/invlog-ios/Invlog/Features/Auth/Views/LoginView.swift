import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Title
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(Color.brandPrimary)
                            .accessibilityHidden(true)

                        Text("Invlog")
                            .font(InvlogTheme.heading(34, weight: .heavy))
                            .foregroundColor(Color.brandText)

                        Text("Discover & share food experiences")
                            .font(InvlogTheme.body(15))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    .padding(.top, 48)

                    // Form Fields
                    VStack(spacing: 16) {
                        if !viewModel.isLoginMode {
                            styledTextField("Username", text: $viewModel.username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .accessibilityLabel("Username")

                            styledTextField("Display Name (optional)", text: $viewModel.displayName)
                                .textContentType(.name)
                                .accessibilityLabel("Display name, optional")
                        }

                        styledTextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .accessibilityLabel("Email address")

                        SecureField("Password", text: $viewModel.password)
                            .font(InvlogTheme.body(15))
                            .textContentType(viewModel.isLoginMode ? .password : .newPassword)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.brandCard)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                    .stroke(Color.brandBorder, lineWidth: 1)
                            )
                            .accessibilityLabel("Password")
                    }

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Submit Button
                    Button {
                        Task {
                            if viewModel.isLoginMode {
                                await viewModel.login()
                            } else {
                                await viewModel.register()
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.isLoginMode ? "Sign In" : "Create Account")
                                    .font(InvlogTheme.body(16, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandText)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel(viewModel.isLoginMode ? "Sign in" : "Create account")

                    // Toggle Mode
                    Button {
                        viewModel.toggleMode()
                    } label: {
                        Text(viewModel.isLoginMode
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Sign In")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandPrimary)
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel(viewModel.isLoginMode
                        ? "Switch to sign up"
                        : "Switch to sign in")
                }
                .padding(.horizontal, 24)
            }
            .invlogScreenBackground()
            .onAppear {
                viewModel.configure(appState: appState)
            }
        }
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(InvlogTheme.body(15))
            .foregroundColor(Color.brandText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
    }
}
