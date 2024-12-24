import Foundation

class HomeAssistantClient {
    private let baseURL: URL
    private let token: String
    private let entityID: String
    
    init(config: HAConfig) {
        self.baseURL = config.baseURL
        self.token = config.token
        self.entityID = config.entityID
    }
    
    func getCurrentLimit() async throws -> TimeInterval {
        Logger.shared.log("HA Client: Getting current limit...")
        let url = baseURL.appendingPathComponent("api/states/\(entityID)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        Logger.shared.log("HA Client: Sending request to \(url)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAError.invalidResponse
        }
        
        Logger.shared.log("HA Client: Got response with status code: \(httpResponse.statusCode)")
        
        // Log the response body for debugging
        if let responseStr = String(data: data, encoding: .utf8) {
            Logger.shared.log("HA Client: Response body: \(responseStr)")
        }
        
        switch httpResponse.statusCode {
        case 200:
            do {
                let stateResponse = try JSONDecoder().decode(HAStateResponse.self, from: data)
                Logger.shared.log("HA Client: Got state: \(stateResponse.state)")
                return TimeInterval(stateResponse.state) ?? 0
            } catch {
                Logger.shared.log("HA Client: JSON decode error: \(error)")
                throw HAError.decodingError(error)
            }
        case 401:
            throw HAError.unauthorized
        case 404:
            throw HAError.entityNotFound(entityID)
        default:
            throw HAError.serverError(httpResponse.statusCode)
        }
    }
    
    func updatePlayedTime(_ time: TimeInterval) async throws {
        // Report played time back to HA
        var request = URLRequest(url: baseURL.appendingPathComponent("api/states/sensor.minertimer_played_time"))
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = HAStateUpdate(state: String(format: "%.2f", time))
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, _) = try await URLSession.shared.data(for: request)
    }
}

// Add custom error types
enum HAError: LocalizedError {
    case invalidResponse
    case unauthorized
    case entityNotFound(String)
    case serverError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Home Assistant"
        case .unauthorized:
            return "Unauthorized - Please check your token"
        case .entityNotFound(let entity):
            return "Entity not found: \(entity)"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
} 