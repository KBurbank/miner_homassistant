import Foundation

@MainActor
class ServiceManager {
    static let shared = ServiceManager()
    private var processMonitor: ProcessMonitor?
    private var haClient: HomeAssistantClient?
    
    private init() {}
    
    func startServices() async {
        Logger.shared.log("ServiceManager: Starting services")
        let config = ConfigManager.loadConfig()
        haClient = HomeAssistantClient(config: config)
        Logger.shared.log("ServiceManager: Services started successfully")
    }
    
    func getHAClient() -> HomeAssistantClient? {
        return haClient
    }
    
    func getProcessMonitor() -> ProcessMonitor? {
        return processMonitor
    }
} 