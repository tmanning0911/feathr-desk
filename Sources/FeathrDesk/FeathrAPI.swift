import Foundation

enum DeskInfo {
    static let version = "1.2"
    static let build = "3"
    static let userAgent = "mfccc-feathr-desk/\(version)"
}

struct FeathrError: LocalizedError {
    static let cancelledStatus = -1

    let status: Int
    let detail: String
    var retryAfter: Int? = nil
    var method = "GET"
    var path = ""

    static var cancelled: FeathrError { FeathrError(status: cancelledStatus, detail: "") }

    var isCancelled: Bool { status == Self.cancelledStatus }

    /// The write scope a 403 most likely needs, from the request that failed.
    var neededScope: String? {
        guard method != "GET" else { return nil }
        if path.hasPrefix("/persons"), path.hasSuffix("/tags") { return "tags:write" }
        if path.hasPrefix("/persons") { return "persons:write" }
        if path.hasPrefix("/tags") { return "tags:write" }
        if path.hasPrefix("/webhooks") { return "webhooks:write" }
        return nil
    }

    var errorDescription: String? {
        let extra = detail.isEmpty ? "" : "\n\nFeathr said: \(detail)"
        switch status {
        case Self.cancelledStatus:
            return "Stopped because you moved on."
        case 0:
            return detail
        case 200...299:
            return "Feathr answered in a shape Desk did not expect. Nothing was changed by Desk."
        case 400, 422:
            return "Feathr did not accept that change. Check the values and try again.\(extra)"
        case 401:
            return "Feathr did not accept the key. It may have been revoked or mistyped. Paste a fresh key from Feathr settings."
        case 403:
            let scope = neededScope.map { " It needs the \($0) scope." } ?? ""
            return "This key is not allowed to do that.\(scope) Ask a Feathr admin to add it, or make the change in Feathr.\(extra)"
        case 404:
            return "Feathr could not find that record. It may have been deleted or merged."
        case 405:
            return "Feathr does not allow this change through the API. Make it in Feathr instead."
        case 429:
            let wait = retryAfter.map { " Try again in about \(Human.seconds($0))." } ?? " Wait a minute and try again."
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

struct FeathrAPI: Sendable {
    var base: String
    var key: String
    var onRate: (@Sendable (RateSnapshot) -> Void)? = nil

    /// Ephemeral so person records never land in an on-disk URL cache.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 45
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }()

    private struct Reply {
        let status: Int
        let value: Any?
        let retryAfter: Int?
    }

    /// Reads retry once on a short 429 or a gateway hiccup. Writes never retry.
    func get(_ path: String, query: [String: String] = [:]) async throws -> [String: Any] {
        var retried = false
        while true {
            let reply = try await request("GET", path, query: query, body: nil)
            if !retried, reply.status == 429, let wait = reply.retryAfter, wait <= 5 {
                retried = true
                try await pause(seconds: max(wait, 1))
                continue
            }
            if !retried, [502, 503, 504].contains(reply.status) {
                retried = true
                try await pause(seconds: 1)
                continue
            }
            guard (200...299).contains(reply.status), let object = reply.value as? [String: Any] else {
                throw failure(reply, "GET", path)
            }
            return object
        }
    }

    func send(_ method: String, _ path: String, body: [String: Any]) async throws -> [String: Any] {
        let reply = try await request(method, path, query: [:], body: body)
        guard (200...299).contains(reply.status) else {
            throw failure(reply, method, path)
        }
        return reply.value as? [String: Any] ?? [:]
    }

    func paginate(_ path: String, query: [String: String] = [:], pageSize: Int = 100, maxPages: Int = 30) async throws -> (items: [[String: Any]], total: Int) {
        var items: [[String: Any]] = []
        var total = 0
        var page = 1
        while page <= maxPages {
            if Task.isCancelled { throw FeathrError.cancelled }
            var q = query
            q["page"] = String(page)
            q["size"] = String(pageSize)
            let payload = try await get(path, query: q)
            let batch = JSON.array(payload["items"])
            items.append(contentsOf: batch)
            total = payload["total"] == nil ? items.count : JSON.int(payload["total"])
            if batch.count < pageSize || items.count >= total { break }
            page += 1
        }
        return (items, total)
    }

    private func failure(_ reply: Reply, _ method: String, _ path: String) -> FeathrError {
        FeathrError(status: reply.status, detail: Self.detail(reply.value), retryAfter: reply.retryAfter, method: method, path: Self.route(path))
    }

    private func pause(seconds: Int) async throws {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
        } catch {
            throw FeathrError.cancelled
        }
    }

    private static func route(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/" + path
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
            } else if let text = object["message"] as? String {
                raw = text
            } else {
                raw = JSON.pretty(object)
            }
        } else {
            raw = JSON.pretty(value)
        }
        return scrub(String(raw.prefix(600)))
    }

    static func scrub(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"fthr_[A-Za-z0-9_\-]+"#, with: "fthr_…", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)bearer\s+[A-Za-z0-9_\-\.]+"#, with: "Bearer …", options: .regularExpression)
    }

    private func request(_ method: String, _ path: String, query: [String: String], body: [String: Any]?) async throws -> Reply {
        if Task.isCancelled { throw FeathrError.cancelled }
        var components = URLComponents(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + Self.route(path))
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
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw FeathrError.cancelled
        } catch is CancellationError {
            throw FeathrError.cancelled
        } catch let error as URLError {
            throw FeathrError(status: 0, detail: Self.networkMessage(error))
        } catch {
            throw FeathrError(status: 0, detail: Self.scrub("Could not reach Feathr. \(error.localizedDescription)"))
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let retry = Self.retryAfter(http)
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
        return Reply(status: status, value: value, retryAfter: retry)
    }

    private static func headerInt(_ http: HTTPURLResponse?, _ name: String) -> Int? {
        guard let raw = http?.value(forHTTPHeaderField: name) else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespaces))
    }

    /// Retry-After as seconds. Feathr may send a number of seconds or an HTTP date.
    static func retryAfter(_ http: HTTPURLResponse?) -> Int? {
        guard let raw = http?.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let seconds = Int(raw) { return max(0, seconds) }
        if let seconds = Double(raw) { return max(0, Int(seconds.rounded(.up))) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: raw) { return max(0, Int(date.timeIntervalSinceNow.rounded(.up))) }
        return nil
    }

    private static func networkMessage(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "This Mac is not connected to the internet."
        case .timedOut:
            return "Feathr took too long to answer. Try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Could not reach Feathr. Check the internet connection or FEATHR_API_BASE."
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate:
            return "The secure connection to Feathr failed. Check the network, or try again off VPN."
        default:
            return scrub("Could not reach Feathr. \(error.localizedDescription)")
        }
    }
}
