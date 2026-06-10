import Foundation

/// Parsed from the DeepSeek /user/balance API response.
struct UsageInfo {
    let balance: Double       // total_balance — remaining credits
    let totalCharged: Double  // total_charged — all-time charges
    let grantedBalance: Double // granted_balance — starting grant
    let toppedUp: Double      // topped_up_balance — manual top-ups
    let isFromScraping: Bool  // true when spend came from the usage page

    /// Calculated spend. The DeepSeek balance API does not expose a
    /// dedicated "spend" field, so we derive it from available data:
    ///  - total_charged  (rarely returned)
    ///  - topped_up - remaining  (top-up accounts)
    ///  - granted - remaining     (grant accounts)
    var calculatedSpend: Double {
        if totalCharged > 0 { return totalCharged }
        let topUpSpend = toppedUp - balance
        let grantSpend = grantedBalance - balance
        return max(topUpSpend, grantSpend, 0)
    }

    /// The displayed "current" balance in USD.
    var formattedBalance: String {
        Self.formatCurrency(balance)
    }

    /// Spend formatted for display.
    var formattedSpend: String {
        return Self.formatCurrency(calculatedSpend)
    }

    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

// MARK: - Flexible number/string decoding

/// The DeepSeek API may return numeric fields as strings ("2.98") or
/// bare numbers (2.98).  This wrapper decodes either form into a Double.
struct FlexibleDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self.value = Double(str) ?? 0
        } else if let num = try? container.decode(Double.self) {
            self.value = num
        } else if let int = try? container.decode(Int.self) {
            self.value = Double(int)
        } else {
            self.value = 0
        }
    }
}

// MARK: - Codable helpers for the API JSON

    struct BalanceInfo: Decodable {
        let currency: String?
        let totalBalance: FlexibleDouble?
        let totalCharged: FlexibleDouble?
        let grantedBalance: FlexibleDouble?
        let toppedUpBalance: FlexibleDouble?

        enum CodingKeys: String, CodingKey {
            case currency
            case totalBalance       = "total_balance"
            case totalCharged       = "total_charged"
            case grantedBalance     = "granted_balance"
            case toppedUpBalance    = "topped_up_balance"
        }
    }

    struct ApiResponse: Decodable {
        let isAvailable: Bool?
        let balanceInfos: [BalanceInfo]?

        enum CodingKeys: String, CodingKey {
            case isAvailable    = "is_available"
            case balanceInfos   = "balance_infos"
        }
    }

    init(apiResponse: ApiResponse) throws {
        guard let infos = apiResponse.balanceInfos, let first = infos.first else {
            throw DeepSeekError.noBalanceData
        }
        self.balance        = first.totalBalance?.value ?? 0
        self.totalCharged   = first.totalCharged?.value ?? 0
        self.grantedBalance = first.grantedBalance?.value ?? 0
        self.toppedUp       = first.toppedUpBalance?.value ?? 0
        self.isFromScraping = false
    }

    /// Combined: API balance + scraped spend + topping/grant info
    init(balance: Double, totalCharged: Double, grantedBalance: Double, toppedUp: Double, isFromScraping: Bool) {
        self.balance         = balance
        self.totalCharged    = totalCharged
        self.grantedBalance  = grantedBalance
        self.toppedUp        = toppedUp
        self.isFromScraping  = isFromScraping
    }

    /// Scraped result with fewer fields.
    init(balance: Double, spend: Double) {
        self.balance        = balance
        self.totalCharged   = spend
        self.grantedBalance = balance + spend
        self.toppedUp       = 0
        self.isFromScraping = true
    }
}

enum DeepSeekError: LocalizedError {
    case noBalanceData
    case apiKeyMissing
    case networkError(String)
    case parseError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .noBalanceData:    return "No balance data returned"
        case .apiKeyMissing:    return "Set API key in Settings"
        case .networkError(let m): return m
        case .parseError(let m):   return "Parse error: \(m)"
        case .unauthorized:     return "Invalid API key"
        }
    }
}
