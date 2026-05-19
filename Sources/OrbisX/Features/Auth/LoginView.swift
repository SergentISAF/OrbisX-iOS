import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var mode: Mode = .login
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var tenantName: String = ""
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    enum Mode {
        case login, signup
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .signup ? "Opret konto" : "Velkommen tilbage")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                Text(mode == .signup ? "Opret dit workspace og tilføj brands du vil overvåge." : "Adgang til din workspace og brands.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                if mode == .signup {
                    LabeledField(label: "Workspace", text: $tenantName, placeholder: "fx Aalborg Håndbold")
                }
                LabeledField(label: "Email", text: $email, placeholder: "navn@firma.dk", keyboardType: .emailAddress)
                LabeledField(label: "Password", text: $password, isSecure: true)
            }

            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: submit) {
                HStack {
                    if isWorking {
                        ProgressView().tint(.white)
                    }
                    Text(mode == .signup ? "Opret konto" : "Log ind")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isWorking || !canSubmit)

            Button(mode == .signup ? "Har du allerede en konto? Log ind" : "Ny her? Opret konto") {
                mode = mode == .signup ? .login : .signup
                errorText = nil
            }
            .font(.footnote)
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(24)
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && (mode == .login || !tenantName.isEmpty)
    }

    private func submit() {
        isWorking = true
        errorText = nil
        Task {
            do {
                switch mode {
                case .login:
                    try await auth.login(email: email, password: password)
                case .signup:
                    try await auth.signup(email: email, password: password, tenantName: tenantName)
                }
            } catch {
                errorText = error.localizedDescription
            }
            isWorking = false
        }
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
