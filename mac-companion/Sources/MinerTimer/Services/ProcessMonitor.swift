import Foundation

class ProcessMonitor: ObservableObject {
    private var timer: Timer?
    let haClient: HomeAssistantClient
    
    @Published var monitoredProcess: GameProcess? {
        willSet {
            Logger.shared.log("ProcessMonitor: Process state changing from \(monitoredProcess?.state.rawValue ?? "nil") to \(newValue?.state.rawValue ?? "nil")")
        }
    }
    @Published var playedTime: TimeInterval = 0
    @Published var currentLimit: TimeInterval = 0
    
    init(haClient: HomeAssistantClient) {
        Logger.shared.log("ProcessMonitor: Initializing with HA client")
        self.haClient = haClient
        startMonitoring()
    }
    
    func startMonitoring() {
        Logger.shared.log("ProcessMonitor: Starting monitoring")
        // Check processes every 15 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkProcesses()
            
            // Update time if process is running
            if let process = self?.monitoredProcess {
                if process.state == .running {
                    self?.playedTime += 0.25 // Add 15 seconds (0.25 minutes)
                }
                
                // Report to HA and check limits
                Task {
                    do {
                        Logger.shared.log("ProcessMonitor: Updating played time to \(self?.playedTime ?? 0)")
                        try await self?.haClient.updatePlayedTime(self?.playedTime ?? 0)
                        
                        // Get current limit
                        let limit = try await self?.haClient.getCurrentLimit() ?? 0
                        await MainActor.run {
                            self?.currentLimit = limit
                        }
                        
                        // Check if we need to suspend or resume
                        if let self = self, let pid = self.monitoredProcess?.pid {
                            Logger.shared.log("ProcessMonitor: Checking limits - Played: \(self.playedTime), Limit: \(limit), State: \(self.monitoredProcess?.state.rawValue ?? "unknown")")
                            
                            if self.playedTime >= limit {
                                if self.monitoredProcess?.state == .running {
                                    Logger.shared.log("ProcessMonitor: Time limit reached, suspending process")
                                    self.suspendProcess(pid)
                                }
                            } else if self.playedTime < limit {  // Explicit comparison
                                if self.monitoredProcess?.state == .suspended {
                                    Logger.shared.log("ProcessMonitor: Time available (\(limit - self.playedTime) minutes), resuming process")
                                    self.resumeProcess(pid)
                                }
                            }
                        }
                    } catch {
                        Logger.shared.log("ProcessMonitor: Error updating time: \(error)")
                    }
                }
            }
        }
    }
    
    private func checkProcesses() {
        Logger.shared.log("ProcessMonitor: Checking processes...")
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-l", "java"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                Logger.shared.log("ProcessMonitor: Found processes: \(output)")
                // Process the output to find Minecraft
                if !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines)
                    if let firstLine = lines.first,
                       let pid = Int32(firstLine.components(separatedBy: " ")[0]) {
                        
                        // Keep existing state if it's the same process
                        if let existing = monitoredProcess, existing.pid == pid {
                            Logger.shared.log("ProcessMonitor: Found existing process (PID: \(pid), State: \(existing.state.rawValue))")
                        } else {
                            // Only create new process if it's a different one
                            let process = GameProcess(
                                pid: pid,
                                name: "Minecraft",
                                state: .running,
                                startTime: Date()
                            )
                            monitoredProcess = process
                            Logger.shared.log("ProcessMonitor: Found new Minecraft process (PID: \(pid))")
                        }
                    }
                } else {
                    monitoredProcess = nil
                    Logger.shared.log("ProcessMonitor: No Java processes found")
                }
            }
        } catch {
            Logger.shared.log("ProcessMonitor: Error checking processes: \(error)")
        }
    }
    
    func suspendProcess(_ pid: Int32) {
        Logger.shared.log("ProcessMonitor: Suspending process \(pid)")
        kill(pid, SIGSTOP)
        // Create new process instance with updated state
        if var process = monitoredProcess {
            process.state = .suspended
            monitoredProcess = process
        }
    }
    
    func resumeProcess(_ pid: Int32) {
        Logger.shared.log("ProcessMonitor: Resuming process \(pid)")
        kill(pid, SIGCONT)
        // Create new process instance with updated state
        if var process = monitoredProcess {
            process.state = .running
            monitoredProcess = process
        }
    }
} 