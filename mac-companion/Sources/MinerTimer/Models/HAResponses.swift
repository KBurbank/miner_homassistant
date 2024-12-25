import Foundation

struct HADiscoveryResponse: Codable {
    let configured: Bool
}

struct HAStateResponse: Codable {
    let state: String
    let attributes: [String: String]?
}

struct HAStateUpdate: Codable {
    let state: String
}

struct HADiscoveryPayload: Codable {
    let handler: String
    let showAdvancedOptions: Bool
    
    enum CodingKeys: String, CodingKey {
        case handler
        case showAdvancedOptions = "show_advanced_options"
    }
} 