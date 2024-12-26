import Foundation

extension URL {
    func appendingQueryParameters(_ parameters: [String: String]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        let queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url!
    }
} 