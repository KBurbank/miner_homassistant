import Foundation

@MainActor
class ProcessMonitor: ObservableObject {
    private var timer: Timer?
    private var haClient: HomeAssistantClient?
    
    @Published var monitoredProcess: GameProcess?
    @Published var playedTime: TimeInterval = 0
    @Published private(set) var currentLimit: TimeInterval {
        didSet {
            UserDefaults.standard.set(currentLimit, forKey: "currentTimeLimit")
        }
    }
    
    init(haClient: HomeAssistantClient?) {
        Logger.shared.log("ProcessMonitor: Initializing")
        
        // Load saved limit first
        let savedLimit = UserDefaults.standard.double(forKey: "currentTimeLimit")
        self.currentLimit = savedLimit > 0 ? savedLimit : 60
        Logger.shared.log("Loaded saved time limit: \(currentLimit) minutes")
        
        // Set up HA client
        self.haClient = haClient
        haClient?.setMonitor(self)  // Set ourselves as the monitor
        
        // Load saved state
        if let state = PersistenceManager.shared.loadTimeState() {
            self.playedTime = state.playedTime
            Logger.shared.log("Loaded initial state: \(playedTime) minutes")
        }
        
        startMonitoring()
    }
    
    func setHAClient(_ client: HomeAssistantClient) {
        Logger.shared.log("Setting HA client in ProcessMonitor")
        self.haClient = client
    }
    
    private func checkLimits() {
        if let process = monitoredProcess {
            if playedTime >= currentLimit && process.state == .running {
                Logger.shared.log("ProcessMonitor: Time limit reached, suspending process")
                suspendProcess(process.pid)
            } else if playedTime < currentLimit && process.state == .suspended {
                Logger.shared.log("ProcessMonitor: Time available, resuming process")
                resumeProcess(process.pid)
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
                        self?.playedTime += 0.25 // Add 15 seconds
                        
                        // Save state
                        if let playedTime = self?.playedTime {
                            PersistenceManager.shared.saveTimeState(playedTime: playedTime)
                            
                            // Report to HA
                            self?.haClient?.updatePlayedTime(playedTime)
                        }
                    }
                    
                    // Check limits
                    self?.checkLimits()
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
    
    func simulateProcess() async {
        // Make it actually async by adding a delay
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
        // Rest of simulation code
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
    
    @MainActor
    func addTime(_ minutes: TimeInterval) {
        let newLimit = currentLimit + minutes
        updateTimeLimit(newLimit)
        
        // Update HA
        if let client = haClient {
            client.updateTimeLimit(newLimit)
        }
    }
    
    func updateTimeLimit(_ limit: TimeInterval) {
        Logger.shared.log("Updating time limit to: \(limit)")
        currentLimit = limit
        checkLimits()  // Check if we need to suspend/resume
    }
} 