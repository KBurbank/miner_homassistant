import SwiftUI

struct ContentView: View {
    @ObservedObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack {
            Text("MinerTimer")
                .font(.title)
            
            Button("Test HA Connection") {
                Task {
                    do {
                        let limit = try await processMonitor.getCurrentLimit()
                        print("Got limit from HA: \(limit)")
                    } catch {
                        print("HA Error: \(error)")
                    }
                }
            }
            
            Button("Simulate Process") {
                Task {
                    await processMonitor.simulateProcess()
                }
            }
            
            Button("Reset Time") {
                processMonitor.resetTime()
            }
            
            // Debug info
            Text("Debug Info:")
                .font(.headline)
                .padding(.top)
            
            Text("Played Time: \(processMonitor.playedTime)")
            Text("Current Limit: \(processMonitor.currentLimit)")
            if let process = processMonitor.monitoredProcess {
                Text("Process: \(process.name) (\(process.state.rawValue))")
            }
        }
        .padding()
    }
} 