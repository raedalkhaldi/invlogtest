import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showLogoutAlert = false
    @State private var showErrorLog = false
    @State private var showShareLog = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceManager.mode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                    .accessibilityLabel("App theme")
                }

                Section("Account") {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        Label("Edit Profile", systemImage: "person")
                    }
                    .frame(minHeight: 44)

                    NavigationLink {
                        Text("Privacy Settings")
                    } label: {
                        Label("Privacy", systemImage: "lock")
                    }
                    .frame(minHeight: 44)

                    NavigationLink {
                        Text("Notification Preferences")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    .frame(minHeight: 44)
                }

                Section("Debug") {
                    Button {
                        showErrorLog = true
                    } label: {
                        Label("View Error Log", systemImage: "doc.text.magnifyingglass")
                            .foregroundColor(Color.brandText)
                    }
                    .frame(minHeight: 44)

                    Button {
                        showShareLog = true
                    } label: {
                        Label("Share Error Log", systemImage: "square.and.arrow.up")
                            .foregroundColor(Color.brandText)
                    }
                    .frame(minHeight: 44)

                    Button(role: .destructive) {
                        ErrorLogger.shared.clearLog()
                    } label: {
                        Label("Clear Error Log", systemImage: "trash")
                    }
                    .frame(minHeight: 44)
                }

                Section("Support") {
                    NavigationLink {
                        Text("About Invlog")
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    .frame(minHeight: 44)

                    Link(destination: URL(string: "https://invlog.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    .frame(minHeight: 44)

                    Link(destination: URL(string: "https://invlog.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    .frame(minHeight: 44)
                }

                Section {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(Color.brandText)
                    }
                    .frame(minHeight: 44)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                    .frame(minHeight: 44)
                }
            }
            .scrollContentBackground(.hidden)
            .invlogScreenBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .tint(Color.brandPrimary)
            .alert("Sign Out?", isPresented: $showLogoutAlert) {
                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await APIClient.shared.requestVoid(.deleteAccount)
                        appState.signOut()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. Your account and all data will be permanently deleted after 30 days.")
            }
            .sheet(isPresented: $showErrorLog) {
                ErrorLogView()
            }
            .sheet(isPresented: $showShareLog) {
                ShareSheetView(items: [ErrorLogger.shared.getLog()])
            }
        }
    }
}

// MARK: - Error Log Viewer

struct ErrorLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logContent = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logContent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.brandText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .invlogScreenBackground()
            .navigationTitle("Error Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .onAppear {
            logContent = ErrorLogger.shared.getLog()
        }
    }
}
