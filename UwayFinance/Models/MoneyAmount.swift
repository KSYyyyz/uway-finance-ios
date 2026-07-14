import Foundation

enum MoneyAmountError: LocalizedError, Equatable {
    case invalidValue
    case outOfRange

    var errorDescription: String? {
        switch self {
        case .invalidValue: "金额格式无效"
        case .outOfRange: "金额超出客户端支持范围"
        }
    }
}

/// Exact financial amount stored as integer cents. Current legacy JSON still uses a
/// numeric `amount` field, while new domain/network models can use this type directly.
struct MoneyAmount: Codable, Hashable, Comparable, Sendable {
    let cents: Int64

    init(cents: Int64) {
        self.cents = cents
    }

    init(decimal: Decimal) throws {
        var input = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        let scaled = NSDecimalNumber(decimal: rounded * 100)
        guard scaled != .notANumber else { throw MoneyAmountError.invalidValue }
        let value = scaled.int64Value
        guard NSDecimalNumber(value: value).compare(scaled) == .orderedSame else {
            throw MoneyAmountError.outOfRange
        }
        cents = value
    }

    init(legacyDouble: Double) {
        precondition(legacyDouble.isFinite, "financial amount must be finite")
        let value = Decimal(string: String(legacyDouble), locale: Locale(identifier: "en_US_POSIX"))
            ?? Decimal(legacyDouble)
        self = try! MoneyAmount(decimal: value)
    }

    init(decimalString: String) throws {
        let pattern = #"^-?(?:0|[1-9]\d*)(?:\.\d{1,2})?$"#
        guard decimalString.range(of: pattern, options: .regularExpression) != nil,
              let value = Decimal(string: decimalString, locale: Locale(identifier: "en_US_POSIX")) else {
            throw MoneyAmountError.invalidValue
        }
        try self.init(decimal: value)
    }

    var decimalValue: Decimal { Decimal(cents) / 100 }
    var legacyDouble: Double { NSDecimalNumber(decimal: decimalValue).doubleValue }
    var decimalString: String {
        let sign = cents < 0 ? "-" : ""
        let magnitude = cents.magnitude
        let fraction = String(format: "%02llu", magnitude % 100)
        return "\(sign)\(magnitude / 100).\(fraction)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let decimal = try? container.decode(Decimal.self) {
            try self.init(decimal: decimal)
            return
        }
        if let text = try? container.decode(String.self) {
            try self.init(decimalString: text)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "amount must be a JSON number or decimal string")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(decimalValue)
    }

    static func < (lhs: MoneyAmount, rhs: MoneyAmount) -> Bool {
        lhs.cents < rhs.cents
    }
}

/// Compatibility wrapper: existing UI call sites keep `Double`, but decoded and
/// encoded amounts cross the network through exact integer cents.
@propertyWrapper
struct LegacyMoney: Codable, Hashable, Sendable {
    private var amount: MoneyAmount

    var wrappedValue: Double {
        get { amount.legacyDouble }
        set { amount = MoneyAmount(legacyDouble: newValue) }
    }

    var projectedValue: MoneyAmount { amount }

    init(wrappedValue: Double) {
        amount = MoneyAmount(legacyDouble: wrappedValue)
    }

    init(from decoder: Decoder) throws {
        amount = try MoneyAmount(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try amount.encode(to: encoder)
    }
}
