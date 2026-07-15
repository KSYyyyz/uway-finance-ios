import SwiftUI

private enum AuthenticationMode: String, CaseIterable, Identifiable {
    case login = "登录"
    case register = "注册"
    var id: String { rawValue }
}

private struct ActiveRegistrationChallenge: Equatable {
    let id: String
    let expiresAt: Date
    let resendAt: Date
}

struct LoginView: View {
    private enum Field: Hashable {
        case loginUsername, loginPassword
        case registerUsername, phone, code, password, confirmation
    }

    @EnvironmentObject private var session: AppSession
    @State private var mode: AuthenticationMode = .login
    @State private var loginUsername = ""
    @State private var loginPassword = ""
    @State private var registerUsername = ""
    @State private var phone = ""
    @State private var code = ""
    @State private var registerPassword = ""
    @State private var passwordConfirmation = ""
    @State private var challenge: ActiveRegistrationChallenge?
    @State private var isSubmitting = false
    @State private var isRequestingCode = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    Picker("认证方式", selection: $mode) {
                        ForEach(AuthenticationMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("在登录已有账号和注册新账号之间切换")

                    Group {
                        if mode == .login { loginCard }
                        else { registrationCard }
                    }

                    serverStatus
                    Text("会话由服务器通过 HttpOnly、Secure、SameSite=Strict Cookie 管理；密码、验证码和手机号不会写入日志、URL 或本地持久化存储。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .appScrollIndicatorsHidden()
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.pageBackground)
            .onChange(of: mode) { _, _ in
                errorMessage = nil
                focusedField = nil
                if mode == .login { clearRegistrationSecrets() }
                else { loginPassword = "" }
            }
            .task(id: challenge?.id) {
                guard let challenge else { return }
                await monitorChallenge(challenge)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.columns.fill")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .accessibilityHidden(true)
            Text("Uway 财务工作台")
                .font(.title2.weight(.semibold))
            Text(mode == .login ? "登录后同步公司的经营账目" : "注册后自动创建独立企业与账套")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var loginCard: some View {
        VStack(spacing: 12) {
            TextField("用户名", text: $loginUsername)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .loginUsername)
                .submitLabel(.next)
                .onSubmit { focusedField = .loginPassword }
            SecureField("密码", text: $loginPassword)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .loginPassword)
                .submitLabel(.go)
                .onSubmit { if canSubmitLogin { Task { await submitLogin() } } }
            statusMessage
            Button {
                Task { await submitLogin() }
            } label: {
                submitLabel(progress: isSubmitting, idle: "登录", busy: "正在登录")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitLogin)
            .accessibilityHint("安全登录并读取当前账号的独立账套")
        }
        .appCard()
    }

    private var registrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !session.registrationCapability.safeForClientUse {
                Label(session.registrationCapability.unavailableMessage, systemImage: "exclamationmark.shield")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.warning)
            }

            TextField("用户名（3–64 个字符）", text: $registerUsername)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerUsername)
                .submitLabel(.next)
                .onSubmit { focusedField = .phone }

            TextField("手机号，例如 138… 或 +65…", text: $phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .phone)
                .accessibilityLabel("注册手机号")
                .accessibilityHint("中国大陆手机号可直接输入，国际号码请带加号和国家区号")
                .onChange(of: phone) { oldValue, newValue in
                    if challenge != nil, oldValue != newValue {
                        challenge = nil
                        code = ""
                    }
                }

            HStack(spacing: 10) {
                TextField("6 位验证码", text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .code)
                    .disabled(challenge == nil)
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                    }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Button(codeButtonTitle(at: context.date)) {
                        Task { await requestCode() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canRequestCode(at: context.date))
                    .accessibilityLabel(codeButtonTitle(at: context.date))
                    .accessibilityHint("向当前手机号发送服务器生成的一次性验证码")
                }
            }

            if let challenge {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("验证码剩余 \(remainingSeconds(until: challenge.expiresAt, at: context.date)) 秒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityLabel("验证码有效期剩余 \(remainingSeconds(until: challenge.expiresAt, at: context.date)) 秒")
                }
            }

            SecureField("密码（至少 10 位，含字母和数字）", text: $registerPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirmation }
            SecureField("确认密码", text: $passwordConfirmation)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .confirmation)
                .submitLabel(.go)
                .onSubmit { if canSubmitRegistration { Task { await submitRegistration() } } }

            statusMessage
            Button {
                Task { await submitRegistration() }
            } label: {
                submitLabel(progress: isSubmitting, idle: "注册并进入工作台", busy: "正在创建独立账套")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitRegistration)
            .accessibilityHint("验证手机号并创建只属于当前新用户的企业和账套")
        }
        .appCard()
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(AppTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("错误：\(errorMessage)")
        } else if let alertMessage = session.alertMessage {
            Text(alertMessage)
                .font(.footnote)
                .foregroundStyle(AppTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var serverStatus: some View {
        HStack {
            ServerStatusLabel(state: session.serverState)
            Spacer()
            Button("重新检查") { Task { await session.retryConnection() } }
                .font(.caption.weight(.semibold))
                .disabled(session.serverState == .checking)
        }
        .padding(.horizontal, 4)
    }

    private func submitLabel(progress: Bool, idle: String, busy: String) -> some View {
        HStack {
            if progress { ProgressView() }
            Text(progress ? busy : idle)
        }
        .frame(maxWidth: .infinity)
    }

    private var canSubmitLogin: Bool {
        !loginUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !loginPassword.isEmpty
            && !isSubmitting
    }

    private var canSubmitRegistration: Bool {
        session.registrationCapability.safeForClientUse
            && challenge != nil
            && registerUsername.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            && code.count == 6
            && registerPassword.count >= 10
            && registerPassword == passwordConfirmation
            && !isSubmitting
    }

    private func canRequestCode(at date: Date) -> Bool {
        guard session.registrationCapability.safeForClientUse,
              !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isRequestingCode else { return false }
        return challenge.map { date >= $0.resendAt } ?? true
    }

    private func codeButtonTitle(at date: Date) -> String {
        if isRequestingCode { return "发送中" }
        guard let challenge else { return "获取验证码" }
        let remaining = remainingSeconds(until: challenge.resendAt, at: date)
        return remaining > 0 ? "\(remaining) 秒后重发" : "重新发送"
    }

    private func remainingSeconds(until target: Date, at date: Date) -> Int {
        max(0, Int(ceil(target.timeIntervalSince(date))))
    }

    @MainActor
    private func submitLogin() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.login(username: loginUsername, password: loginPassword)
            loginPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func requestCode() async {
        isRequestingCode = true
        errorMessage = nil
        defer { isRequestingCode = false }
        do {
            let response = try await session.requestRegistrationCode(phone: phone)
            let now = Date()
            challenge = ActiveRegistrationChallenge(
                id: response.challengeId,
                expiresAt: now.addingTimeInterval(TimeInterval(response.expiresInSeconds)),
                resendAt: now.addingTimeInterval(TimeInterval(response.resendAfterSeconds))
            )
            code = ""
            focusedField = .code
        } catch {
            errorMessage = RegistrationErrorMessage.localized(error)
        }
    }

    @MainActor
    private func submitRegistration() async {
        guard let challenge else { return }
        guard registerPassword == passwordConfirmation else {
            errorMessage = "两次输入的密码不一致。"
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.register(RegistrationRequest(
                username: registerUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                password: registerPassword,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                challengeId: challenge.id,
                code: code
            ))
            clearRegistrationSecrets()
        } catch {
            errorMessage = RegistrationErrorMessage.localized(error)
            if case APIError.server(_, let serverCode, _) = error,
               serverCode == "INVALID_REGISTRATION_CODE" {
                self.challenge = nil
                code = ""
            }
        }
    }

    @MainActor
    private func monitorChallenge(_ monitored: ActiveRegistrationChallenge) async {
        while !Task.isCancelled, challenge?.id == monitored.id {
            if Date() >= monitored.expiresAt {
                challenge = nil
                code = ""
                errorMessage = "验证码已过期，请重新获取。"
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func clearRegistrationSecrets() {
        registerPassword = ""
        passwordConfirmation = ""
        code = ""
        challenge = nil
    }
}
