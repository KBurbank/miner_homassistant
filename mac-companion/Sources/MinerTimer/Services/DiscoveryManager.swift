import Foundation
import Network

class DiscoveryManager {
    static let shared = DiscoveryManager()
    private var listener: NWListener?
    
    func startAdvertising() {
        // Use Tailscale's MagicDNS port
        let params = NWParameters.tcp
        
        do {
            listener = try NWListener(using: params, on: 5555)  // Choose a specific port
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Logger.shared.log("MinerTimer service ready on Tailscale")
                    // Get and log Tailscale IP for debugging
                    if let ip = self.getTailscaleIP() {
                        Logger.shared.log("Tailscale IP: \(ip)")
                    }
                case .failed(let error):
                    Logger.shared.log("Service failed: \(error)")
                default:
                    break
                }
            }
            listener?.start(queue: .main)
        } catch {
            Logger.shared.log("Failed to start service: \(error)")
        }
    }
    
    private func getTailscaleIP() -> String? {
        // Run tailscale ip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Applications/Tailscale.app/Contents/MacOS/Tailscale")
        process.arguments = ["ip"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return ip
            }
        } catch {
            Logger.shared.log("Error getting Tailscale IP: \(error)")
        }
        return nil
    }
} 