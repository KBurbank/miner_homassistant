import Foundation

class HomeAssistantClient {
    private let baseURL: URL
    private let token: String
    private var entityID: String?
    
    init(config: HAConfig) {
        self.baseURL = config.baseURL
        self.token = config.token
        self.entityID = config.entityID  // Keep initial value from config
        startDiscovery()
    }
    
    private func startDiscovery() {
        Task { @MainActor in
            do {
                // Check if integration exists
                let url = baseURL.appendingPathComponent("api/integrations/minertimer")
                var request = URLRequest(url: url)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                // If not found, trigger discovery
                if let response = try? JSONDecoder().decode(HADiscoveryResponse.self, from: data),
                   !response.configured {
                    try await triggerDiscovery()
                    // Set default entity ID after discovery
                    self.entityID = "input_number.minecraft_time_limit"
                }
                
                Logger.shared.log("Integration discovered and configured")
            } catch {
                Logger.shared.log("Error discovering integration: \(error)")
            }
        }
    }
    
    private func triggerDiscovery() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/config/config_entries/flow"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = HADiscoveryPayload(handler: "minertimer", showAdvancedOptions: false)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw HAError.discoveryFailed
        }
    }
    
    func getCurrentLimit() async throws -> TimeInterval {
        guard let entityID = entityID else {
            throw HAError.notConfigured
        }
        
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
    
    func updateLimit(_ newLimit: TimeInterval) async throws {
        guard let entityID = entityID else {
            throw HAError.notConfigured
        }
        
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("services")
            .appendingPathComponent("input_number")
            .appendingPathComponent("set_value")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = [
            "entity_id": entityID,
            "value": newLimit
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw HAError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        Logger.shared.log("Successfully updated time limit to \(newLimit) minutes")
    }
}

// Add custom error types
enum HAError: LocalizedError {
    case invalidResponse
    case unauthorized
    case entityNotFound(String)
    case serverError(Int)
    case decodingError(Error)
    case requestFailed(statusCode: Int)
    case discoveryFailed
    case notConfigured
    
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
        case .requestFailed(let statusCode):
            return "Request failed (HTTP \(statusCode))"
        case .discoveryFailed:
            return "Discovery failed"
        case .notConfigured:
            return "Home Assistant integration not configured"
        }
    }
} 