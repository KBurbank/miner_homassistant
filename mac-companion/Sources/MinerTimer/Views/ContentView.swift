import SwiftUI

struct ContentView: View {
    @EnvironmentObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MinerTimer")
                .font(.title)
                .padding(.top)
            
            if let process = processMonitor.monitoredProcess {
                ProcessStatusView(process: process)
                TimeStatusView(
                    playedTime: processMonitor.playedTime,
                    limit: processMonitor.currentLimit
                )
            } else {
                Text("No monitored processes")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            #if DEBUG
            VStack {
                Button("Simulate Process") {
                    processMonitor.monitoredProcess = GameProcess(
                        pid: 1234,
                        name: "Minecraft",
                        state: .running,
                        startTime: Date()
                    )
                }
                
                Button("Test HA Connection") {
                    Task {
                        do {
                            let limit = try await processMonitor.haClient.getCurrentLimit()
                            print("Got limit from HA: \(limit)")
                        } catch {
                            print("HA Error: \(error)")
                        }
                    }
                }
                
                Button("Reset Time") {
                    processMonitor.playedTime = 0
                }
                
                Divider()
                
                Button("Show Config") {
                    if let configURL = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                        .first?
                        .appendingPathComponent("MinerTimer/config.json") {
                        do {
                            let data = try Data(contentsOf: configURL)
                            let config = try JSONDecoder().decode(HAConfig.self, from: data)
                            print("Current config:")
                            print("URL: \(config.baseURL)")
                            print("Entity: \(config.entityID)")
                            print("Token: \(config.token.prefix(10))...")
                        } catch {
                            print("Error reading config: \(error)")
                        }
                    }
                }
                
                Text("Debug Info:")
                    .font(.headline)
                Text("Played Time: \(processMonitor.playedTime)")
                Text("Current Limit: \(processMonitor.currentLimit)")
                if let process = processMonitor.monitoredProcess {
                    Text("Process: \(process.name) (\(process.state.rawValue))")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            #endif
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
        .background(Color(.windowBackgroundColor))
    }
}

struct ProcessStatusView: View {
    let process: GameProcess
    
    var body: some View {
        VStack {
            Text(process.name)
                .font(.headline)
            Text("Status: \(process.state.rawValue.capitalized)")
                .font(.subheadline)
        }
    }
}

struct TimeStatusView: View {
    let playedTime: TimeInterval
    let limit: TimeInterval
    
    var body: some View {
        VStack {
            Text("Time Played: \(formatTime(playedTime))")
            Text("Time Limit: \(formatTime(limit))")
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: 20)
                    
                    Rectangle()
                        .foregroundColor(.blue)
                        .frame(width: min(CGFloat(playedTime/limit) * geometry.size.width, geometry.size.width), height: 20)
                }
                .cornerRadius(4)
            }
            .frame(height: 20)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 60
        let minutes = Int(time) % 60
        return String(format: "%d:%02d", hours, minutes)
    }
} 