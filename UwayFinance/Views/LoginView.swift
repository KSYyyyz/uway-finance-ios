import SwiftUI
import UIKit

private enum AuthenticationMode: String, CaseIterable, Identifiable {
    case login = "登录"
    case register = "注册"
    case recovery = "找回密码"
    var id: String { rawValue }
}

private struct ActiveAuthenticationChallenge: Equatable {
    let id: String
    let expiresAt: Date
    let resendAt: Date
}

private enum UsernameCheckState: Equatable {
    case idle
    case checking
    case available(String)
    case unavailable(String)
    case uncertain(String)
}

struct LoginView: View {
    private enum Field: Hashable {
        case loginIdentifier, loginPassword
        case registerUsername, email, phone, code, password, confirmation
        case recoveryEmail, recoveryCode, recoveryPassword, recoveryConfirmation
    }

    @EnvironmentObject private var session: AppSession
    @State private var mode: AuthenticationMode = .login
    @State private var loginIdentifier = ""
    @State private var loginPassword = ""
    @State private var registerUsername = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var code = ""
    @State private var registerPassword = ""
    @State private var passwordConfirmation = ""
    @State private var registrationChallenge: ActiveAuthenticationChallenge?
    @State private var usernameCheck: UsernameCheckState = .idle
    @State private var recoveryEmail = ""
    @State private var recoveryCode = ""
    @State private var recoveryPassword = ""
    @State private var recoveryConfirmation = ""
    @State private var recoveryChallenge: ActiveAuthenticationChallenge?
    @State private var isSubmitting = false
    @State private var isRequestingCode = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showLoginPassword = false
    @State private var showRegisterPassword = false
    @State private var showRegisterConfirmation = false
    @State private var showRecoveryPassword = false
    @State private var showRecoveryConfirmation = false
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
                    .accessibilityHint("在登录、注册新账号和邮箱找回密码之间切换")

                    Group {
                        switch mode {
                        case .login: loginCard
                        case .register: registrationCard
                        case .recovery: recoveryCard
                        }
                    }

                    serverStatus
                    Text("会话由服务器通过 HttpOnly、Secure、SameSite=Strict Cookie 管理；账号、密码、验证码、手机号和邮箱不会写入日志、URL 或本地持久化存储。")
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
            .onChange(of: mode) { _, newMode in
                errorMessage = nil
                if newMode != .login { successMessage = nil }
                focusedField = nil
                if newMode != .register { clearRegistrationSecrets() }
                if newMode != .recovery { clearRecoverySecrets() }
                if newMode != .login { loginPassword = "" }
            }
            .task(id: registerUsername) {
                await debounceUsernameCheck()
            }
            .task(id: registrationChallenge?.id) {
                guard let challenge = registrationChallenge else { return }
                await monitorChallenge(challenge, kind: .registration)
            }
            .task(id: recoveryChallenge?.id) {
                guard let challenge = recoveryChallenge else { return }
                await monitorChallenge(challenge, kind: .recovery)
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
            Text(headerDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var headerDescription: String {
        switch mode {
        case .login: "使用用户名、手机号或邮箱进入独立账套"
        case .register: "验证手机并创建独立企业与账套"
        case .recovery: "通过注册邮箱安全重置密码"
        }
    }

    private var loginCard: some View {
        VStack(spacing: 12) {
            TextField("用户名、手机号或邮箱", text: $loginIdentifier)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .loginIdentifier)
                .submitLabel(.next)
                .onSubmit { focusedField = .loginPassword }
                .accessibilityLabel("登录账号")
                .accessibilityHint("可输入用户名、手机号或邮箱")
            PasswordEntry(
                title: "密码",
                text: $loginPassword,
                isVisible: $showLoginPassword,
                contentType: .password,
                accessibilityName: "登录密码"
            )
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

            Button("忘记密码？") {
                mode = .recovery
            }
            .font(.footnote.weight(.semibold))
            .accessibilityHint("切换到邮箱找回密码")
        }
        .appCard()
    }

    private var registrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !session.registrationCapability.safeForClientUse {
                capabilityWarning(session.registrationCapability.unavailableMessage)
            }

            TextField("用户名（3–32 个字符）", text: $registerUsername)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerUsername)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
                .accessibilityHint("支持中文、英文字母、数字、下划线和短横线")
            usernameStatus

            TextField("邮箱", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .phone }
                .accessibilityLabel("注册邮箱")
                .accessibilityHint("邮箱用于账号登录和密码找回")

            TextField("手机号，例如 138… 或 +65…", text: $phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .phone)
                .accessibilityLabel("注册手机号")
                .accessibilityHint("中国大陆手机号可直接输入，国际号码请带加号和国家区号")
                .onChange(of: phone) { oldValue, newValue in
                    if registrationChallenge != nil, oldValue != newValue {
                        registrationChallenge = nil
                        code = ""
                    }
                }

            codeRow(
                code: $code,
                challenge: registrationChallenge,
                focusedField: .code,
                isRecovery: false
            )

            PasswordEntry(
                title: "密码（8–256 个字符）",
                text: $registerPassword,
                isVisible: $showRegisterPassword,
                contentType: .newPassword,
                accessibilityName: "注册密码"
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.next)
            .onSubmit { focusedField = .confirmation }
            PasswordEntry(
                title: "确认密码",
                text: $passwordConfirmation,
                isVisible: $showRegisterConfirmation,
                contentType: .newPassword,
                accessibilityName: "确认注册密码"
            )
            .focused($focusedField, equals: .confirmation)
            .submitLabel(.go)
            .onSubmit { if canSubmitRegistration { Task { await submitRegistration() } } }

            if let issue = registrationPasswordIssue {
                inlineMessage(issue, color: AppTheme.warning, systemImage: "exclamationmark.circle")
            }

            statusMessage
            Button {
                Task { await submitRegistration() }
            } label: {
                submitLabel(progress: isSubmitting, idle: "注册并进入工作台", busy: "正在创建独立账套")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitRegistration)
            .accessibilityHint("验证手机并创建只属于当前新用户的企业和账套")
        }
        .appCard()
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !session.passwordRecoveryCapability.safeForClientUse {
                capabilityWarning(session.passwordRecoveryCapability.unavailableMessage)
            }

            TextField("注册邮箱", text: $recoveryEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .recoveryEmail)
                .accessibilityHint("无论邮箱是否存在，服务器都会返回相同结构，避免泄露账号信息")
                .onChange(of: recoveryEmail) { oldValue, newValue in
                    if recoveryChallenge != nil, oldValue != newValue {
                        clearRecoveryChallenge()
                    }
                }

            if recoveryChallenge == nil {
                Button {
                    Task { await requestRecoveryCode() }
                } label: {
                    submitLabel(progress: isRequestingCode, idle: "发送重置码", busy: "正在发送")
                }
                .buttonStyle(.bordered)
                .disabled(!canRequestRecoveryCode)
                .accessibilityHint("向注册邮箱请求一次性重置码")
            } else {
                codeRow(
                    code: $recoveryCode,
                    challenge: recoveryChallenge,
                    focusedField: .recoveryCode,
                    isRecovery: true
                )

                PasswordEntry(
                    title: "新密码（8–256 个字符）",
                    text: $recoveryPassword,
                    isVisible: $showRecoveryPassword,
                    contentType: .newPassword,
                    accessibilityName: "新密码"
                )
                .focused($focusedField, equals: .recoveryPassword)
                .submitLabel(.next)
                .onSubmit { focusedField = .recoveryConfirmation }
                PasswordEntry(
                    title: "确认新密码",
                    text: $recoveryConfirmation,
                    isVisible: $showRecoveryConfirmation,
                    contentType: .newPassword,
                    accessibilityName: "确认新密码"
                )
                .focused($focusedField, equals: .recoveryConfirmation)
                .submitLabel(.go)
                .onSubmit { if canConfirmRecovery { Task { await confirmRecovery() } } }

                if let issue = recoveryPasswordIssue {
                    inlineMessage(issue, color: AppTheme.warning, systemImage: "exclamationmark.circle")
                }

                Button {
                    Task { await confirmRecovery() }
                } label: {
                    submitLabel(progress: isSubmitting, idle: "确认重置密码", busy: "正在重置")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canConfirmRecovery)
                .accessibilityHint("成功后所有旧设备会话都会失效，需要重新登录")
            }

            statusMessage
        }
        .appCard()
    }

    @ViewBuilder
    private var usernameStatus: some View {
        switch usernameCheck {
        case .idle:
            EmptyView()
        case .checking:
            inlineMessage("正在检查用户名…", color: .secondary, systemImage: "hourglass")
        case .available(let message):
            inlineMessage(message, color: AppTheme.brand, systemImage: "checkmark.circle")
        case .unavailable(let message):
            inlineMessage(message, color: AppTheme.danger, systemImage: "xmark.circle")
        case .uncertain(let message):
            inlineMessage(message, color: AppTheme.warning, systemImage: "wifi.exclamationmark")
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(AppTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("错误：\(errorMessage)")
        } else if let successMessage {
            Text(successMessage)
                .font(.footnote)
                .foregroundStyle(AppTheme.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("成功：\(successMessage)")
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

    private func codeRow(
        code: Binding<String>,
        challenge: ActiveAuthenticationChallenge?,
        focusedField field: Field,
        isRecovery: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("6 位验证码", text: code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: field)
                    .disabled(challenge == nil)
                    .onChange(of: code.wrappedValue) { _, value in
                        code.wrappedValue = String(value.filter(\.isNumber).prefix(6))
                    }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Button(codeButtonTitle(challenge: challenge, at: context.date)) {
                        Task {
                            if isRecovery { await requestRecoveryCode() }
                            else { await requestRegistrationCode() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canRequestCode(challenge: challenge, at: context.date, isRecovery: isRecovery))
                    .accessibilityLabel(codeButtonTitle(challenge: challenge, at: context.date))
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
        }
    }

    private func capabilityWarning(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.shield")
            .font(.footnote)
            .foregroundStyle(AppTheme.warning)
    }

    private func inlineMessage(_ message: String, color: Color, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submitLabel(progress: Bool, idle: String, busy: String) -> some View {
        HStack {
            if progress { ProgressView() }
            Text(progress ? busy : idle)
        }
        .frame(maxWidth: .infinity)
    }

    private var canSubmitLogin: Bool {
        !loginIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !loginPassword.isEmpty
            && !isSubmitting
    }

    private var registrationPasswordIssue: String? {
        guard !registerPassword.isEmpty else { return nil }
        return IdentityInputPolicy.passwordIssue(
            registerPassword,
            username: registerUsername,
            phone: phone,
            email: email
        )
    }

    private var usernameSubmissionAllowed: Bool {
        if IdentityInputPolicy.usernameIssue(registerUsername) != nil { return false }
        switch usernameCheck {
        case .unavailable, .checking: return false
        case .idle: return !session.registrationCapability.supportsIdentityContract
        case .available, .uncertain: return true
        }
    }

    private var canSubmitRegistration: Bool {
        session.registrationCapability.safeForClientUse
            && registrationChallenge != nil
            && usernameSubmissionAllowed
            && IdentityInputPolicy.isValidEmail(email)
            && code.count == 6
            && (8...256).contains(registerPassword.count)
            && registrationPasswordIssue == nil
            && registerPassword == passwordConfirmation
            && !isSubmitting
    }

    private var canRequestRecoveryCode: Bool {
        session.passwordRecoveryCapability.safeForClientUse
            && IdentityInputPolicy.isValidEmail(recoveryEmail)
            && !isRequestingCode
    }

    private var recoveryPasswordIssue: String? {
        guard !recoveryPassword.isEmpty else { return nil }
        return IdentityInputPolicy.passwordIssue(
            recoveryPassword,
            username: "",
            phone: "",
            email: recoveryEmail
        )
    }

    private var canConfirmRecovery: Bool {
        recoveryChallenge != nil
            && recoveryCode.count == 6
            && (8...256).contains(recoveryPassword.count)
            && recoveryPasswordIssue == nil
            && recoveryPassword == recoveryConfirmation
            && !isSubmitting
    }

    private func canRequestCode(
        challenge: ActiveAuthenticationChallenge?,
        at date: Date,
        isRecovery: Bool
    ) -> Bool {
        let capabilityAvailable = isRecovery
            ? session.passwordRecoveryCapability.safeForClientUse && IdentityInputPolicy.isValidEmail(recoveryEmail)
            : session.registrationCapability.safeForClientUse
                && !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard capabilityAvailable, !isRequestingCode else { return false }
        return challenge.map { date >= $0.resendAt } ?? true
    }

    private func codeButtonTitle(challenge: ActiveAuthenticationChallenge?, at date: Date) -> String {
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
        successMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.login(identifier: loginIdentifier, password: loginPassword)
            loginPassword = ""
        } catch {
            errorMessage = AuthenticationErrorMessage.localized(error)
        }
    }

    @MainActor
    private func debounceUsernameCheck() async {
        guard mode == .register else { return }
        if let issue = IdentityInputPolicy.usernameIssue(registerUsername) {
            usernameCheck = registerUsername.isEmpty ? .idle : .unavailable(issue.message)
            return
        }
        guard session.registrationCapability.supportsIdentityContract else {
            usernameCheck = .uncertain("当前服务器不支持实时检查，提交时将由服务器最终确认")
            return
        }
        usernameCheck = .checking
        do {
            try await Task.sleep(for: .milliseconds(450))
            try Task.checkCancellation()
            let response = try await session.checkUsernameAvailability(registerUsername)
            usernameCheck = response.available ? .available(response.message) : .unavailable(response.message)
        } catch is CancellationError {
            return
        } catch {
            usernameCheck = .uncertain("暂时无法检查，提交时将由服务器最终确认")
        }
    }

    @MainActor
    private func requestRegistrationCode() async {
        isRequestingCode = true
        errorMessage = nil
        successMessage = nil
        defer { isRequestingCode = false }
        do {
            let response = try await session.requestRegistrationCode(phone: phone)
            registrationChallenge = challenge(from: response)
            code = ""
            focusedField = .code
        } catch {
            errorMessage = RegistrationErrorMessage.localized(error)
        }
    }

    @MainActor
    private func submitRegistration() async {
        guard let challenge = registrationChallenge else { return }
        guard registerPassword == passwordConfirmation else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.register(RegistrationRequest(
                username: registerUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                    .precomposedStringWithCompatibilityMapping,
                email: IdentityInputPolicy.normalizedEmail(email),
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
                registrationChallenge = nil
                code = ""
            }
        }
    }

    @MainActor
    private func requestRecoveryCode() async {
        isRequestingCode = true
        errorMessage = nil
        successMessage = nil
        defer { isRequestingCode = false }
        do {
            let response = try await session.requestPasswordReset(
                email: IdentityInputPolicy.normalizedEmail(recoveryEmail)
            )
            let now = Date()
            recoveryChallenge = ActiveAuthenticationChallenge(
                id: response.challengeId,
                expiresAt: now.addingTimeInterval(TimeInterval(response.expiresInSeconds)),
                resendAt: now.addingTimeInterval(TimeInterval(response.resendAfterSeconds))
            )
            recoveryCode = ""
            successMessage = response.message
            focusedField = .recoveryCode
        } catch {
            errorMessage = AuthenticationErrorMessage.localized(error)
        }
    }

    @MainActor
    private func confirmRecovery() async {
        guard let challenge = recoveryChallenge else { return }
        guard recoveryPassword == recoveryConfirmation else {
            errorMessage = "两次输入的新密码不一致"
            return
        }
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }
        do {
            let response = try await session.confirmPasswordReset(PasswordResetConfirmRequest(
                email: IdentityInputPolicy.normalizedEmail(recoveryEmail),
                challengeId: challenge.id,
                code: recoveryCode,
                newPassword: recoveryPassword
            ))
            clearRecoverySecrets()
            mode = .login
            successMessage = response.message
        } catch {
            errorMessage = AuthenticationErrorMessage.localized(error)
            if case APIError.server(_, let serverCode, _) = error,
               serverCode == "INVALID_PASSWORD_RESET_CODE" {
                clearRecoveryChallenge()
            }
        }
    }

    private func challenge(from response: RegistrationCodeResponse) -> ActiveAuthenticationChallenge {
        let now = Date()
        return ActiveAuthenticationChallenge(
            id: response.challengeId,
            expiresAt: now.addingTimeInterval(TimeInterval(response.expiresInSeconds)),
            resendAt: now.addingTimeInterval(TimeInterval(response.resendAfterSeconds))
        )
    }

    private enum ChallengeKind: Equatable { case registration, recovery }

    @MainActor
    private func monitorChallenge(_ monitored: ActiveAuthenticationChallenge, kind: ChallengeKind) async {
        while !Task.isCancelled {
            let current = kind == .registration ? registrationChallenge : recoveryChallenge
            guard current?.id == monitored.id else { return }
            if Date() >= monitored.expiresAt {
                if kind == .registration {
                    registrationChallenge = nil
                    code = ""
                } else {
                    clearRecoveryChallenge()
                }
                errorMessage = "验证码已过期，请重新获取"
                return
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func clearRegistrationSecrets() {
        registerPassword = ""
        passwordConfirmation = ""
        code = ""
        registrationChallenge = nil
        showRegisterPassword = false
        showRegisterConfirmation = false
    }

    private func clearRecoveryChallenge() {
        recoveryCode = ""
        recoveryChallenge = nil
        recoveryPassword = ""
        recoveryConfirmation = ""
        showRecoveryPassword = false
        showRecoveryConfirmation = false
    }

    private func clearRecoverySecrets() {
        clearRecoveryChallenge()
        recoveryEmail = ""
    }
}

private struct PasswordEntry: View {
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    let contentType: UITextContentType
    let accessibilityName: String

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isVisible {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "隐藏\(accessibilityName)" : "显示\(accessibilityName)")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}
