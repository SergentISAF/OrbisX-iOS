import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 4)
                Text("OrbisX")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                Text("Log ind for at se dine overvågnings-agenter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
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
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    }
                    Text("Log ind")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(auth.isWorking || !canSubmit)

            VStack(spacing: 6) {
                Text("Konto oprettes på orbisx.ai")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("Åbn orbisx.ai", destination: URL(string: "https://orbisx.ai")!)
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(24)
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6
    }

    private func submit() {
        errorText = nil
        Task {
            do {
                try await auth.signIn(email: email.lowercased(), password: password)
            } catch {
                errorText = error.localizedDescription
            }
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
