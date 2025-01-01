import Foundation

// This class monitors the process (e.g. Minecraft)
@MainActor
public class ProcessMonitor: ObservableObject {
    public struct MonitoredProcess {
        let pid: pid_t
        let name: String
        let startTime: Date
        let state: ProcessState
        
        public enum ProcessState: String {
            case running
            case suspended
        }
    }
    
    @Published private(set) var monitoredProcess: MonitoredProcess?
    
    init() {
        Logger.shared.log("🔨 Creating ProcessMonitor")
        Logger.shared.log("🔨 ProcessMonitor created")
    }
    
    @MainActor
    func checkAndUpdateProcess() {
        Logger.shared.log("🔍 ProcessMonitor: Starting process check...")
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-l", "java"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                Logger.shared.log("🔍 pgrep output: '\(output)'")
                if !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines)
                    Logger.shared.log("🔍 Found \(lines.count) lines")
                    if let firstLine = lines.first {
                        Logger.shared.log("🔍 First line: '\(firstLine)'")
                        let components = firstLine.components(separatedBy: " ")
                        Logger.shared.log("🔍 Line components: \(components)")
                        if let pid = Int32(components[0]) {
                            // Keep existing state if it's the same process
                            if let existing = monitoredProcess, existing.pid == pid {
                                Logger.shared.log("✅ Found existing Java process (PID: \(pid), State: \(existing.state.rawValue))")
                            } else {
                                let process = MonitoredProcess(
                                    pid: pid,
                                    name: "Minecraft",
                                    startTime: Date(),
                                    state: .running
                                )
                                monitoredProcess = process
                                Logger.shared.log("✅ Found new Java process (PID: \(pid))")
                            }
                        } else {
                            Logger.shared.log("⚠️ Could not parse PID from line: '\(firstLine)'")
                        }
                    }
                } else {
                    monitoredProcess = nil
                    Logger.shared.log("❌ No Java processes found")
                }
            }
        } catch {
            Logger.shared.log("❌ Error checking processes: \(error)")
        }
    }
    
    func suspendProcess() {
        guard let process = monitoredProcess else {
            Logger.shared.log("❌ No process to suspend")
            return
        }
        
        Logger.shared.log("🛑 Suspending process \(process.pid)")
        kill(process.pid, SIGSTOP)
        
        // Create new MonitoredProcess with suspended state
        monitoredProcess = MonitoredProcess(
            pid: process.pid,
            name: process.name,
            startTime: process.startTime,
            state: .suspended
        )
        Logger.shared.log("✅ Process suspended")
    }
    
    func resumeProcess() {
        guard let process = monitoredProcess else {
            Logger.shared.log("❌ No process to resume")
            return
        }
        
        Logger.shared.log("▶️ Resuming process \(process.pid)")
        kill(process.pid, SIGCONT)
        
        // Create new MonitoredProcess with running state
        monitoredProcess = MonitoredProcess(
            pid: process.pid,
            name: process.name,
            startTime: process.startTime,
            state: .running
        )
        Logger.shared.log("✅ Process resumed")
    }
} 