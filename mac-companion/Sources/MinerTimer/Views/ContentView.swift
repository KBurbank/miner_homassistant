import SwiftUI

struct ContentView: View {
    @ObservedObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack {
            Text("Time Played: \(Int(processMonitor.playedTime)) minutes")
                .padding()
            
            Text("Time Limit: \(Int(processMonitor.currentLimit)) minutes")
                .padding()
            
            if let process = processMonitor.monitoredProcess {
                Text("Status: \(process.state.rawValue)")
                    .padding()
                
                Button(action: {
                    if process.state == .running {
                        processMonitor.suspendProcess(process.pid)
                    } else {
                        processMonitor.resumeProcess(process.pid)
                    }
                }) {
                    Text(process.state == .running ? "Pause" : "Resume")
                }
                .padding()
            } else {
                Text("No game running")
                    .padding()
            }
            
            Button("Reset Time") {
                processMonitor.resetTime()
            }
            .padding()
        }
    }
} 