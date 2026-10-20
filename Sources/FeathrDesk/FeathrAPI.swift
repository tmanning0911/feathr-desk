import Foundation

enum DeskInfo {
    static let version = "1.1"
    static let userAgent = "mfccc-feathr-desk/\(version)"
}

struct FeathrError: LocalizedError {
    let status: Int
    let detail: String
    var retryAfter: Int? = nil

    var errorDescription: String? {
        let extra = detail.isEmpty ? "" : "\n\nFeathr said: \(detail)"
        switch status {
        case 0:
            return detail
        case 400, 422:
            return "Feathr did not accept that change. Check the values and try again.\(extra)"
        case 401:
            return "Feathr did not accept the key. It may have been revoked or mistyped. Use the key button to paste a fresh key from Feathr settings."
        case 403:
            return "This key is not allowed to do that. Ask a Feathr admin to add the needed scope, or make the change in Feathr.\(extra)"
        case 404:
            return "Feathr could not find that record. It may have been deleted or merged."
        case 405:
            return "Feathr does not allow this change through the API. Make it in Feathr instead."
        case 429:
            let wait = retryAfter.map { " Try again in about \($0) second\($0 == 1 ? "" : "s")." } ?? " Wait a minute and try again."
            return "Feathr is limiting how fast this key can make requests.\(wait)"
        case 500...599:
            return "Feathr had a problem on its side (\(status)). Try again in a few minutes.\(extra)"
        default:
            return "Feathr returned \(status).\(extra)"
        }
    }
}

struct RateSnapshot {
    var limit: Int?
    var remaining: Int?
    var retryAfter: Int?
    var limitedAt: Date?
    var updated = Date()
}

struct FeathrAPI {
    var base: String
    var key: String
    var onRate: (@Sendable (RateSnapshot) -> Void)? = nil

    func get(_ path: String, query: [String: String] = [:]) async throws -> [String: Any] {
        var (status, value, retry) = try await request("GET", path, query: query, body: nil)
        if status == 429, let wait = retry, wait <= 5 {
            try? await Task.sleep(nanoseconds: UInt64(max(wait, 1)) * 1_000_000_000)
            (status, value, retry) = try await request("GET", path, query: query, body: nil)
        }
        guard (200...299).contains(status), let object = value as? [String: Any] else {
            throw FeathrError(status: status, detail: Self.detail(value), retryAfter: retry)
        }
        return object
    }

    func send(_ method: String, _ path: String, body: [String: Any]) async throws -> [String: Any] {
        let (status, value, retry) = try await request(method, path, query: [:], body: body)
        guard (200...299).contains(status) else {
            throw FeathrError(status: status, detail: Self.detail(value), retryAfter: retry)
        }
        return value as? [String: Any] ?? [:]
    }

    func paginate(_ path: String, query: [String: String] = [:], pageSize: Int = 100, maxPages: Int = 30) async throws -> (items: [[String: Any]], total: Int) {
        var items: [[String: Any]] = []
        var total = 0
        var page = 1
        while page <= maxPages {
            var q = query
            q["page"] = String(page)
            q["size"] = String(pageSize)
            let payload = try await get(path, query: q)
            total = JSON.int(payload["total"])
            let batch = JSON.array(payload["items"])
            items.append(contentsOf: batch)
            if batch.count < pageSize || items.count >= total { break }
            page += 1
        }
        return (items, total)
    }

    private static func detail(_ value: Any?) -> String {
        guard let value else { return "" }
        let raw: String
        if let object = value as? [String: Any] {
            if let text = object["detail"] as? String {
                raw = text
            } else if let list = object["detail"] as? [[String: Any]] {
                raw = list.map { item in
                    let loc = JSON.strings(item["loc"]).filter { $0 != "body" }.joined(separator: ".")
                    let msg = JSON.string(item["msg"])
                    return loc.isEmpty ? msg : "\(loc): \(msg)"
                }.joined(separator: "; ")
            } else {
                raw = JSON.pretty(object)
            }
        } else {
            raw = JSON.pretty(value)
        }
        return scrub(String(raw.prefix(600)))
    }

    static func scrub(_ text: String) -> String {
        text.replacingOccurrences(of: #"fthr_[A-Za-z0-9_\-]+"#, with: "fthr_…", options: .regularExpression)
    }

    private func request(_ method: String, _ path: String, query: [String: String], body: [String: Any]?) async throws -> (Int, Any?, Int?) {
        var components = URLComponents(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + (path.hasPrefix("/") ? path : "/" + path))
        if !query.isEmpty {
            components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else {
            throw FeathrError(status: 0, detail: "The Feathr address is not valid. Check FEATHR_API_BASE.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(DeskInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw FeathrError(status: 0, detail: Self.networkMessage(error))
        } catch {
            throw FeathrError(status: 0, detail: "Could not reach Feathr. \(error.localizedDescription)")
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let retry = Self.headerInt(http, "Retry-After")
        let snapshot = RateSnapshot(
            limit: Self.headerInt(http, "X-RateLimit-Limit"),
            remaining: Self.headerInt(http, "X-RateLimit-Remaining"),
            retryAfter: retry,
            limitedAt: status == 429 ? Date() : nil
        )
        if snapshot.limit != nil || snapshot.remaining != nil || status == 429 {
            onRate?(snapshot)
        }
        let value = data.isEmpty ? nil : (try? JSONSerialization.jsonObject(with: data))
        return (status, value, retry)
    }

    private static func headerInt(_ http: HTTPURLResponse?, _ name: String) -> Int? {
        guard let raw = http?.value(forHTTPHeaderField: name) else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespaces))
    }

    private static func networkMessage(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "This Mac is not connected to the internet."
        case .timedOut:
            return "Feathr took too long to answer. Try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Could not reach Feathr. Check the internet connection or FEATHR_API_BASE."
        default:
            return "Could not reach Feathr. \(error.localizedDescription)"
        }
    }
}
