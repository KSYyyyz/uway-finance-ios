import Foundation

struct RegistrationCodeRequest: Codable, Equatable, Sendable {
    let phone: String
}

struct RegistrationCodeResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let challengeId: String
    let expiresInSeconds: Int
    let resendAfterSeconds: Int
}

struct RegistrationRequest: Codable, Equatable, Sendable {
    let username: String
    let email: String
    let password: String
    let phone: String
    let challengeId: String
    let code: String
}

struct PendingRegistrationResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let pendingRegistrationId: String
    let expiresInSeconds: Int
    let resendAfterSeconds: Int
    let message: String
}

struct RegistrationEmailResendRequest: Codable, Equatable, Sendable {
    let pendingRegistrationId: String
}

struct RegistrationEmailConfirmRequest: Codable, Equatable, Sendable {
    let token: String
}

enum RegistrationEmailLink {
    static func token(from url: URL) -> String? {
        guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
            return nil
        }
        for item in fragment.split(separator: "&", omittingEmptySubsequences: true) {
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, pair[0] == "verify-email" else { continue }
            let token = String(pair[1]).removingPercentEncoding ?? String(pair[1])
            return token.isEmpty ? nil : token
        }
        return nil
    }
}

struct RegistrationActivationResponse: Codable, Equatable, Sendable {
    let user: SessionUser
    let organizationId: String
    let accountBookId: String
}

enum RegistrationErrorMessage {
    static func localized(_ error: Error) -> String {
        guard case APIError.server(_, let code, _) = error else {
            return error.localizedDescription
        }
        switch code {
        case "INVALID_PHONE": return "手机号格式不正确，请输入中国大陆手机号或带国家区号的国际号码。"
        case "INVALID_EMAIL": return "邮箱格式不正确，请检查后重试。"
        case "INVALID_REGISTRATION_INPUT": return "注册信息格式不正确，请检查用户名、密码和验证码。"
        case "WEAK_PASSWORD": return "密码须为 8–256 位，且不能明显包含用户名、手机号后六位或邮箱名称。"
        case "INVALID_REGISTRATION_CODE": return "手机验证码无效或已过期，请重新获取。"
        case "REGISTRATION_CODE_RATE_LIMITED": return "验证码请求过于频繁，请按倒计时稍后重试。"
        case "INVALID_REGISTRATION_EMAIL_TOKEN": return "邮件确认链接无效、已过期或已被使用，请重新发送确认邮件。"
        case "REGISTRATION_EMAIL_RESEND_RATE_LIMITED": return "确认邮件重发过于频繁，请按倒计时稍后重试。"
        case "REGISTRATION_EMAIL_CONFIRM_RATE_LIMITED": return "邮件确认尝试过于频繁，请稍后再试。"
        case "REGISTRATION_EMAIL_LINK_RATE_LIMITED": return "邮件确认链接请求过于频繁，请稍后再试。"
        case "REGISTRATION_IDENTITY_CONFLICT": return "用户名、手机号或邮箱已被使用，请更换后重试。"
        case "SMS_PROVIDER_UNAVAILABLE": return "手机验证码服务暂不可用，请稍后再试。"
        case "SMS_DELIVERY_FAILED": return "验证码发送失败，请稍后重新获取。"
        case "EMAIL_VERIFICATION_UNAVAILABLE": return "注册邮箱验证暂未开通。"
        default: return error.localizedDescription
        }
    }
}
