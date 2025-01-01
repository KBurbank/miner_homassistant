import SwiftUI

@available(macOS 10.15, *)
struct ContentView: View {
    @ObservedObject var processMonitor: ProcessMonitor
    @ObservedObject var timeScheduler: TimeScheduler
    @ObservedObject var playedTime: TimeValue
    @ObservedObject var currentLimit: TimeValue
    
    init(processMonitor: ProcessMonitor, timeScheduler: TimeScheduler) {
        self.processMonitor = processMonitor
        self.timeScheduler = timeScheduler
        self.playedTime = timeScheduler.playedTime
        self.currentLimit = timeScheduler.currentLimit
    }
    
    private var timeRemaining: Int {
        Int(currentLimit.value - playedTime.value)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 15) {
                Text("Time Played Today")
                    .font(.headline)
                Text("\(Int(playedTime.value)) minutes")
                    .font(.system(size: 24, weight: .bold))
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            
            VStack(spacing: 15) {
                Text("Time Remaining")
                    .font(.headline)
                Text("\(timeRemaining) minutes")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(timeRemaining < 15 ? .red : .primary)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            .id(timeRemaining)
            
            VStack(spacing: 15) {
                Text("Process Status")
                    .font(.headline)
                if let process = processMonitor.monitoredProcess {
                    Text(process.state.rawValue)
                        .font(.system(size: 20))
                        .foregroundColor(process.state == .running ? .green : .orange)
                } else {
                    Text("No process monitored")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
}

@available(macOS 10.15, *)
struct TimeDisplay: View {
    let name: String
    @ObservedObject var timeValue: TimeValue
    
    var body: some View {
        HStack {
            Text("\(name):")
            Text("\(Int(timeValue.value)) min")
        }
    }
}

@available(macOS 10.15, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let monitor = ProcessMonitor()
        let scheduler = TimeScheduler(processMonitor: monitor)
        ContentView(processMonitor: monitor, timeScheduler: scheduler)
    }
} 