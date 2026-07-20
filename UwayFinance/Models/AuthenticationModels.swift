import Foundation

struct UsernameAvailabilityRequest: Codable, Equatable, Sendable {
    let username: String
}

struct UsernameAvailabilityResponse: Codable, Equatable, Sendable {
    let available: Bool
    let reason: String?
    let message: String
}

struct PasswordResetRequest: Codable, Equatable, Sendable {
    let email: String
}

struct PasswordResetChallengeResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let challengeId: String
    let expiresInSeconds: Int
    let resendAfterSeconds: Int
    let message: String
}

struct PasswordResetConfirmRequest: Codable, Equatable, Sendable {
    let email: String
    let challengeId: String
    let code: String
    let newPassword: String
}

struct PasswordResetConfirmResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let message: String
}

enum IdentityInputPolicy {
    static let reservedUsernames: Set<String> = [
        "admin", "administrator", "root", "system", "support", "service",
        "uway", "official", "api", "www", "test", "null", "undefined",
    ]

    static func normalizedUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
            .lowercased()
    }

    static func usernameIssue(_ value: String) -> (reason: String, message: String)? {
        let username = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
        guard (3...32).contains(username.count) else {
            return ("length", "用户名长度必须为 3–32 个字符")
        }
        guard matches(username, pattern: #"^[A-Za-z0-9\p{Han}](?:[A-Za-z0-9\p{Han}_-]*[A-Za-z0-9\p{Han}])?$"#),
              !matches(username, pattern: #".*[_-]{2}.*"#) else {
            return ("format", "用户名只能包含中文、英文字母、数字、下划线或短横线，且必须以文字或数字开头和结尾")
        }
        guard !matches(username, pattern: #"^[0-9]+$"#) else {
            return ("numeric_only", "用户名不能全部由数字组成")
        }
        guard !reservedUsernames.contains(normalizedUsername(username)) else {
            return ("reserved", "该用户名不可使用")
        }
        return nil
    }

    static func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
            .lowercased()
    }

    static func isValidEmail(_ value: String) -> Bool {
        let email = normalizedEmail(value)
        guard email.count <= 254, let at = email.lastIndex(of: "@") else { return false }
        let local = String(email[..<at])
        let domain = String(email[email.index(after: at)...])
        guard !local.isEmpty, local.count <= 64, !domain.isEmpty, domain.count <= 253,
              !email.contains(".."), !local.hasPrefix("."), !local.hasSuffix(".") else { return false }
        return matches(email, pattern: #"^[^\s<>(),:;\"\[\]\\@]+@[^\s@.]+(?:\.[^\s@.]+)+$"#)
    }

    static func passwordIssue(
        _ password: String,
        username: String,
        phone: String,
        email: String
    ) -> String? {
        guard (8...256).contains(password.count) else {
            return "密码长度必须为 8–256 个字符"
        }
        let comparable = password.precomposedStringWithCompatibilityMapping.lowercased()
        let digits = phone.filter(\.isNumber)
        let emailLocal = normalizedEmail(email).split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
        let fragments = [
            normalizedUsername(username),
            digits.count >= 6 ? String(digits.suffix(6)) : "",
            emailLocal.count >= 3 ? emailLocal : "",
        ].filter { !$0.isEmpty }
        return fragments.contains { comparable.contains($0) }
            ? "密码不能明显包含用户名、手机号后六位或邮箱名称"
            : nil
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.firstMatch(in: value, range: range)?.range == range
    }
}

enum AuthenticationErrorMessage {
    static func localized(_ error: Error) -> String {
        guard case APIError.server(_, let code, let message) = error else {
            return error.localizedDescription
        }
        switch code {
        case "INVALID_CREDENTIALS": return "账号或密码错误"
        case "INVALID_EMAIL": return "邮箱格式不正确"
        case "EMAIL_RESET_UNAVAILABLE": return "邮件找回暂未开通"
        case "PASSWORD_RESET_REQUEST_RATE_LIMITED": return "找回请求过于频繁，请稍后再试"
        case "INVALID_PASSWORD_RESET_INPUT": return "重置信息格式不正确"
        case "INVALID_PASSWORD_RESET_CODE": return "重置码无效或已过期"
        case "WEAK_PASSWORD": return message.isEmpty ? "密码不符合安全要求" : message
        default: return message.isEmpty ? "认证服务暂不可用" : message
        }
    }
}
