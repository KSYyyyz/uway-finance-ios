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
    let password: String
    let phone: String
    let challengeId: String
    let code: String
}

struct RegistrationResponse: Codable, Equatable, Sendable {
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
        case "INVALID_REGISTRATION_INPUT": return "注册信息格式不正确，请检查用户名、密码和验证码。"
        case "WEAK_PASSWORD": return "密码至少 10 位并包含字母和数字，且不能包含用户名或手机号后六位。"
        case "INVALID_REGISTRATION_CODE": return "验证码无效或已过期，请重新获取。"
        case "REGISTRATION_CODE_RATE_LIMITED": return "验证码请求过于频繁，请按倒计时稍后重试。"
        case "REGISTRATION_IDENTITY_CONFLICT": return "用户名或手机号已被使用，请更换后重试。"
        case "SMS_PROVIDER_UNAVAILABLE": return "手机验证码服务暂不可用，请稍后再试。"
        case "SMS_DELIVERY_FAILED": return "验证码发送失败，请稍后重新获取。"
        default: return error.localizedDescription
        }
    }
}
