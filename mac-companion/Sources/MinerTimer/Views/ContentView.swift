import SwiftUI

@available(macOS 10.15, *)
struct ContentView: View {
    @ObservedObject var processMonitor: ProcessMonitor
    @ObservedObject private var timeScheduler = TimeScheduler.shared
    private let relativeDateFormatter = RelativeDateTimeFormatter()
    
    var body: some View {
        VStack {
            TimeDisplay(
                name: "Current Limit",
                timeValue: timeScheduler.currentLimit,
                relativeDateFormatter: relativeDateFormatter
            )
            TimeDisplay(
                name: "Weekday Limit",
                timeValue: timeScheduler.weekdayLimit,
                relativeDateFormatter: relativeDateFormatter
            )
            TimeDisplay(
                name: "Weekend Limit",
                timeValue: timeScheduler.weekendLimit,
                relativeDateFormatter: relativeDateFormatter
            )
            TimeDisplay(
                name: "Played Time",
                timeValue: timeScheduler.playedTime,
                relativeDateFormatter: relativeDateFormatter
            )
        }
        .padding()
    }
}

@available(macOS 10.15, *)
struct TimeDisplay: View {
    let name: String
    @ObservedObject var timeValue: TimeValue
    let relativeDateFormatter: RelativeDateTimeFormatter
    
    var body: some View {
        HStack {
            Text("\(name):")
            Text("\(Int(timeValue.value)) min")
            if let relativeDate = relativeDateFormatter.string(for: timeValue.lastChanged) {
                Text("(changed \(relativeDate))")
                    .foregroundColor(.secondary)
            }
        }
    }
}

@available(macOS 10.15, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let monitor = ProcessMonitor()
        ContentView(processMonitor: monitor)
    }
} 