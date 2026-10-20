import Foundation

struct FeathrError: LocalizedError {
    let status: Int
    let detail: String
    var errorDescription: String? {
        status == 0 ? detail : "Feathr returned \(status). \(detail)"
    }
}

struct FeathrAPI {
    var base: String
    var key: String

    func get(_ path: String, query: [String: String] = [:]) async throws -> [String: Any] {
        let (status, value) = try await request("GET", path, query: query, body: nil)
        guard (200...299).contains(status), let object = value as? [String: Any] else {
            throw FeathrError(status: status, detail: JSON.string((value as? [String: Any])?["detail"]).ifEmpty(JSON.pretty(value)))
        }
        return object
    }

    func send(_ method: String, _ path: String, body: [String: Any]) async throws -> [String: Any] {
        let (status, value) = try await request(method, path, query: [:], body: body)
        guard (200...299).contains(status) else {
            let detail = JSON.string((value as? [String: Any])?["detail"])
            throw FeathrError(status: status, detail: detail.isEmpty ? JSON.pretty(value) : detail)
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

    private func request(_ method: String, _ path: String, query: [String: String], body: [String: Any]?) async throws -> (Int, Any?) {
        var components = URLComponents(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + (path.hasPrefix("/") ? path : "/" + path))
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else {
            throw FeathrError(status: 0, detail: "Bad Feathr URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("mfccc-feathr-desk/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeathrError(status: 0, detail: error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let value = data.isEmpty ? nil : (try? JSONSerialization.jsonObject(with: data))
        return (status, value)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
