import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "building.columns.fill")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Uway 财务工作台")
                        .font(.title2.weight(.semibold))
                    Text("登录后同步公司账目与处理状态")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 12) {
                    TextField("用户名", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView() }
                            Text(isSubmitting ? "正在登录" : "登录")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || isSubmitting)
                }
                .appCard()
                Spacer()
                Text("会话使用服务器 HttpOnly Cookie；App 不读取或记录密码。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(AppTheme.pageBackground)
        }
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do { try await session.login(username: username, password: password) }
        catch { errorMessage = error.localizedDescription }
    }
}
