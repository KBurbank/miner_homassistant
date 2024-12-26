import Foundation

class LocalAuthServer: NSObject {
    private var server: HTTPServer?
    private var callback: ((String) -> Void)?
    private var expectedState: String?
    
    func start(callback: @escaping (String) -> Void, state: String) {
        // Stop any existing server first
        stop()
        
        Logger.shared.log("Starting local auth server on port 8456")
        self.callback = callback
        self.expectedState = state
        
        // Pass the callback to HTTPServer
        server = HTTPServer(callback: { [weak self] url in
            Logger.shared.log("Callback received with URL: \(url)")
            
            // Parse the code from the URL
            if let urlComponents = URLComponents(string: url),
               let codeItem = urlComponents.queryItems?.first(where: { $0.name == "code" }),
               let code = codeItem.value,
               let stateItem = urlComponents.queryItems?.first(where: { $0.name == "state" }),
               let state = stateItem.value {
                
                // Verify state matches
                if state == self?.expectedState {
                    Logger.shared.log("State verified, calling callback with code")
                    self?.callback?(code)
                    // Stop server after successful callback
                    self?.stop()
                } else {
                    Logger.shared.log("❌ State mismatch! Expected: \(self?.expectedState ?? "nil"), Got: \(state)")
                }
            } else {
                Logger.shared.log("❌ Failed to parse code from callback URL")
            }
        })
        
        do {
            try server?.start()
            Logger.shared.log("Local auth server started successfully")
        } catch {
            Logger.shared.log("❌ Failed to start local server: \(error)")
            // Clean up on failure
            stop()
        }
    }
    
    func stop() {
        Logger.shared.log("Stopping local auth server")
        server?.stop()
        server = nil
        callback = nil
        expectedState = nil
        
        // Give the OS time to release the port
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    deinit {
        stop()
    }
} 