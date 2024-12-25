import Foundation

@MainActor
class ProcessMonitor: ObservableObject {
    private var timer: Timer?
    private var haClient: HomeAssistantClient?
    
    @Published var monitoredProcess: GameProcess?
    @Published var playedTime: TimeInterval = 0
    @Published var currentLimit: TimeInterval = 0
    
    init(haClient: HomeAssistantClient?) {
        Logger.shared.log("ProcessMonitor: Initializing")
        self.haClient = haClient
        
        // Load saved state immediately
        if let state = PersistenceManager.shared.loadTimeState() {
            self.playedTime = state.playedTime
            Logger.shared.log("Loaded initial state: \(playedTime) minutes")
        }
        
        startMonitoring()
    }
    
    func setHAClient(_ client: HomeAssistantClient) {
        self.haClient = client
        // Get initial limit from HA
        Task {
            do {
                let limit = try await client.getCurrentLimit()
                self.currentLimit = limit
                Logger.shared.log("Got initial limit from HA: \(limit)")
            } catch {
                Logger.shared.log("Error getting initial limit: \(error)")
            }
        }
    }
    
    func startMonitoring() {
        Logger.shared.log("ProcessMonitor: Starting monitoring")
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkProcesses()
                
                // Update time if process is running
                if let process = self?.monitoredProcess {
                    if process.state == .running {
                        self?.playedTime += 0.25 // Add 15 seconds (0.25 minutes)
                        // Save state when time changes
                        if let playedTime = self?.playedTime {
                            PersistenceManager.shared.saveTimeState(playedTime: playedTime)
                        }
                    }
                    
                    // Report to HA and check limits
                    if let self = self {
                        Task {
                            do {
                                Logger.shared.log("ProcessMonitor: Updating played time to \(self.playedTime)")
                                try await self.updatePlayedTime(self.playedTime)
                                
                                // Get current limit
                                let limit = try await self.getCurrentLimit()
                                await MainActor.run {
                                    self.currentLimit = limit
                                }
                                
                                // Check if we need to suspend or resume
                                if let pid = self.monitoredProcess?.pid {
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
    
    // Also save state when time is reset
    func resetTime() {
        playedTime = 0
        PersistenceManager.shared.saveTimeState(playedTime: 0)
    }
    
    // Add these public methods for HA operations
    func getCurrentLimit() async throws -> TimeInterval {
        guard let client = haClient else {
            throw ProcessError.noHAClient
        }
        return try await client.getCurrentLimit()
    }
    
    func updateLimit(_ newLimit: TimeInterval) async throws {
        guard let client = haClient else {
            throw ProcessError.noHAClient
        }
        try await client.updateLimit(newLimit)
    }
    
    func updatePlayedTime(_ time: TimeInterval) async throws {
        guard let client = haClient else {
            throw ProcessError.noHAClient
        }
        try await client.updatePlayedTime(time)
    }
    
    func simulateProcess() {
        monitoredProcess = GameProcess(
            pid: 1234,
            name: "Minecraft",
            state: .running,
            startTime: Date()
        )
        Logger.shared.log("ProcessMonitor: Simulated new process")
    }
    
    enum ProcessError: LocalizedError {
        case noHAClient
        
        var errorDescription: String? {
            switch self {
            case .noHAClient:
                return "Home Assistant client not initialized"
            }
        }
    }
} 