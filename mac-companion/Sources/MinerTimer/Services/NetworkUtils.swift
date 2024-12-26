import Foundation

class NetworkUtils {
    static func getTailscaleIP() -> String? {
        Logger.shared.log("Getting Tailscale IP...")
        
        let task = Process()
        task.launchPath = "/sbin/ifconfig"
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for Tailscale IP (100.x.x.x)
                if let line = output.split(separator: "\n")
                    .first(where: { $0.contains("inet") && $0.contains("100.") }),
                   let ip = line.split(separator: " ")
                    .first(where: { $0.starts(with: "100.") }) {
                    let ipString = String(ip)
                    Logger.shared.log("Found Tailscale IP: \(ipString)")
                    return ipString
                }
            }
        } catch {
            Logger.shared.log("❌ Error getting Tailscale IP: \(error)")
        }
        
        Logger.shared.log("❌ No Tailscale IP found")
        return nil
    }
}