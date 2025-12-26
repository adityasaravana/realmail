import SwiftUI
import SwiftData

/// Settings view for account management and app preferences.
struct SettingsView: View {
    private enum Tabs: Hashable {
        case accounts
        case general
    }

    var body: some View {
        TabView {
            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.crop.circle")
                }
                .tag(Tabs.accounts)

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tabs.general)
        }
        .frame(width: 500, height: 400)
    }
}

/// Account management settings.
struct AccountsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.email) private var accounts: [Account]

    @State private var selectedAccount: Account?
    @State private var showAddAccount = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        HSplitView {
            // Account list
            List(accounts, selection: $selectedAccount) { account in
                HStack {
                    Image(systemName: account.provider.iconName)
                        .foregroundStyle(account.provider.color)
                    VStack(alignment: .leading) {
                        Text(account.displayName ?? account.email)
                            .fontWeight(.medium)
                        Text(account.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(account)
            }
            .frame(minWidth: 180)

            // Account details
            if let account = selectedAccount {
                AccountDetailView(account: account)
            } else {
                ContentUnavailableView(
                    "No Account Selected",
                    systemImage: "person.crop.circle",
                    description: Text("Select an account to view details.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Account")

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedAccount == nil)
                .help("Remove Account")
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView()
        }
        .confirmationDialog(
            "Remove Account",
            isPresented: $showDeleteConfirmation,
            presenting: selectedAccount
        ) { account in
            Button("Remove", role: .destructive) {
                deleteAccount(account)
            }
        } message: { account in
            Text("Are you sure you want to remove \(account.email)? All local data for this account will be deleted.")
        }
    }

    private func deleteAccount(_ account: Account) {
        modelContext.delete(account)
        selectedAccount = nil
    }
}

/// Detail view for a selected account.
struct AccountDetailView: View {
    @Bindable var account: Account

    var body: some View {
        Form {
            Section("Account") {
                TextField("Display Name", text: Binding(
                    get: { account.displayName ?? "" },
                    set: { account.displayName = $0.isEmpty ? nil : $0 }
                ))

                LabeledContent("Email") {
                    Text(account.email)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Provider") {
                    Text(account.provider.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Server Settings") {
                LabeledContent("IMAP Server") {
                    Text("\(account.imapHost):\(account.imapPort)")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("SMTP Server") {
                    Text("\(account.smtpHost):\(account.smtpPort)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Enable this account", isOn: $account.isEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// View for adding a new email account.
struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var email = ""
    @State private var provider = AccountProvider.custom
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Account")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Email Address", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            Picker("Provider", selection: $provider) {
                ForEach(AccountProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .frame(width: 300)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Button("Continue") {
                    addAccount()
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || !email.isValidEmail)
            }
        }
        .padding(40)
        .frame(width: 400, height: 250)
    }

    private func addAccount() {
        // TODO: Implement OAuth flow or password entry based on provider
        let config = provider.serverConfig

        let account = Account(
            email: email,
            provider: provider,
            imapHost: config.imapHost,
            imapPort: config.imapPort,
            smtpHost: config.smtpHost,
            smtpPort: config.smtpPort,
            authType: provider.supportsOAuth ? .oauth2 : .password
        )

        modelContext.insert(account)
        dismiss()
    }
}

/// General app settings.
struct GeneralSettingsView: View {
    @AppStorage("checkMailInterval") private var checkMailInterval = 5
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("markAsReadDelay") private var markAsReadDelay = 0

    var body: some View {
        Form {
            Section("Checking") {
                Picker("Check for new mail", selection: $checkMailInterval) {
                    Text("Every minute").tag(1)
                    Text("Every 5 minutes").tag(5)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Manually").tag(0)
                }
            }

            Section("Notifications") {
                Toggle("Show notifications for new messages", isOn: $showNotifications)
            }

            Section("Reading") {
                Picker("Mark messages as read", selection: $markAsReadDelay) {
                    Text("Immediately").tag(0)
                    Text("After 1 second").tag(1)
                    Text("After 3 seconds").tag(3)
                    Text("When opened in new window").tag(-1)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Account.self, inMemory: true)
}
