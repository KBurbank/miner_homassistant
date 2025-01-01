import Foundation

class MQTTConfig: ObservableObject {
    @Published var isEnabled: Bool
    @Published var host: String
    @Published var port: Int
    @Published var useAuthentication: Bool
    @Published var username: String
    @Published var password: String
    
    private struct ConfigData: Codable {
        var isEnabled: Bool
        var host: String
        var port: Int
        var useAuthentication: Bool
        var username: String
        var password: String
    }
    
    init(isEnabled: Bool = false,
         host: String = "homeassistant",
         port: Int = 1883,
         useAuthentication: Bool = true,
         username: String = "mosq_user",
         password: String = "mosq_user_pass") {
        self.isEnabled = isEnabled
        self.host = host
        self.port = port
        self.useAuthentication = useAuthentication
        self.username = username
        self.password = password
    }
    
    static func load() -> MQTTConfig {
        guard let data = UserDefaults.standard.data(forKey: "mqtt_config"),
              let configData = try? JSONDecoder().decode(ConfigData.self, from: data) else {
            return MQTTConfig()
        }
        
        return MQTTConfig(
            isEnabled: configData.isEnabled,
            host: configData.host,
            port: configData.port,
            useAuthentication: configData.useAuthentication,
            username: configData.username,
            password: configData.password
        )
    }
    
    func save() {
        let configData = ConfigData(
            isEnabled: isEnabled,
            host: host,
            port: port,
            useAuthentication: useAuthentication,
            username: username,
            password: password
        )
        
        if let data = try? JSONEncoder().encode(configData) {
            UserDefaults.standard.set(data, forKey: "mqtt_config")
        }
    }
} 