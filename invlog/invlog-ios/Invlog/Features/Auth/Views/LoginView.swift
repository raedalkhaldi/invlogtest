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
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)

                        Text("Invlog")
                            .font(.largeTitle.bold())

                        Text("Discover & share food experiences")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 48)

                    // Form Fields
                    VStack(spacing: 16) {
                        if !viewModel.isLoginMode {
                            TextField("Username", text: $viewModel.username)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .accessibilityLabel("Username")

                            TextField("Display Name (optional)", text: $viewModel.displayName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .accessibilityLabel("Display name, optional")
                        }

                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .accessibilityLabel("Email address")

                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(viewModel.isLoginMode ? .password : .newPassword)
                            .accessibilityLabel("Password")
                    }

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
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
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44) // HIG minimum touch target
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel(viewModel.isLoginMode ? "Sign in" : "Create account")

                    // Toggle Mode
                    Button {
                        viewModel.toggleMode()
                    } label: {
                        Text(viewModel.isLoginMode
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Sign In")
                            .font(.subheadline)
                    }
                    .frame(minHeight: 44) // HIG minimum touch target
                    .accessibilityLabel(viewModel.isLoginMode
                        ? "Switch to sign up"
                        : "Switch to sign in")
                }
                .padding(.horizontal, 24)
            }
            .onAppear {
                viewModel.configure(appState: appState)
            }
        }
    }
}
