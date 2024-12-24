import Cocoa

@main
class MinerTimerApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var processMonitor: ProcessMonitor!
    private var resumeButton: NSButton!
    private var debugInfo: NSTextField!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = ConfigManager.loadConfig()
        let haClient = HomeAssistantClient(config: config)
        processMonitor = ProcessMonitor(haClient: haClient)
        
        setupWindow()
        setupMenu()
    }
    
    private func setupWindow() {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MinerTimer"
        window.center()
        
        // Create main view
        let view = NSView(frame: window.contentView!.bounds)
        
        // Title label
        let label = NSTextField(frame: NSRect(x: 20, y: 340, width: 260, height: 40))
        label.stringValue = "MinerTimer"
        label.alignment = .center
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        view.addSubview(label)
        
        // Debug buttons
        let simulateButton = NSButton(frame: NSRect(x: 20, y: 280, width: 260, height: 32))
        simulateButton.title = "Simulate Process"
        simulateButton.bezelStyle = .rounded
        simulateButton.target = self
        simulateButton.action = #selector(simulateProcess)
        view.addSubview(simulateButton)
        
        let testHAButton = NSButton(frame: NSRect(x: 20, y: 240, width: 260, height: 32))
        testHAButton.title = "Test HA Connection"
        testHAButton.bezelStyle = .rounded
        testHAButton.target = self
        testHAButton.action = #selector(testHAConnection)
        view.addSubview(testHAButton)
        
        let resetButton = NSButton(frame: NSRect(x: 20, y: 200, width: 260, height: 32))
        resetButton.title = "Reset Time"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetTime)
        view.addSubview(resetButton)
        
        let showConfigButton = NSButton(frame: NSRect(x: 20, y: 160, width: 260, height: 32))
        showConfigButton.title = "Show Config"
        showConfigButton.bezelStyle = .rounded
        showConfigButton.target = self
        showConfigButton.action = #selector(showConfig)
        view.addSubview(showConfigButton)
        
        // Initialize resumeButton as property
        resumeButton = NSButton(frame: NSRect(x: 20, y: 120, width: 260, height: 32))
        resumeButton.title = "Resume Process"
        resumeButton.bezelStyle = .rounded
        resumeButton.target = self
        resumeButton.action = #selector(resumeCurrentProcess)
        resumeButton.isEnabled = false
        view.addSubview(resumeButton)
        
        // Initialize debugInfo as property
        debugInfo = NSTextField(frame: NSRect(x: 20, y: 20, width: 260, height: 120))
        debugInfo.isEditable = false
        debugInfo.isBezeled = false
        debugInfo.drawsBackground = false
        debugInfo.cell?.wraps = true
        debugInfo.cell?.isScrollable = false
        view.addSubview(debugInfo)
        
        // Update debug info periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update debug info
            var info = "Debug Info:\n"
            info += "Played Time: \(self.processMonitor.playedTime)\n"
            info += "Current Limit: \(self.processMonitor.currentLimit)\n"
            if let process = self.processMonitor.monitoredProcess {
                info += "Process: \(process.name) (\(process.state.rawValue))"
                self.resumeButton.isEnabled = (process.state == .suspended)
            } else {
                self.resumeButton.isEnabled = false
            }
            self.debugInfo.stringValue = info
        }
        
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc func simulateProcess() {
        processMonitor.monitoredProcess = GameProcess(
            pid: 1234,
            name: "Minecraft",
            state: .running,
            startTime: Date()
        )
    }
    
    @objc func testHAConnection() {
        Logger.shared.log("Testing HA Connection...")
        Task {
            do {
                let limit = try await processMonitor.haClient.getCurrentLimit()
                Logger.shared.log("Got limit from HA: \(limit)")
                // Show alert with result
                let alert = NSAlert()
                alert.messageText = "Home Assistant Connection Test"
                alert.informativeText = "Successfully got limit: \(limit) minutes"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                print("HA Error: \(error)")
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Home Assistant Connection Error"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc func resetTime() {
        print("Resetting time...")
        processMonitor.playedTime = 0
        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "Time Reset"
        alert.informativeText = "Played time has been reset to 0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func showConfig() {
        print("Showing config...")
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
                
                // Show config in alert
                let alert = NSAlert()
                alert.messageText = "Current Configuration"
                alert.informativeText = """
                    URL: \(config.baseURL)
                    Entity: \(config.entityID)
                    Token: \(config.token.prefix(10))...
                    """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                print("Error reading config: \(error)")
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Configuration Error"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    @objc func resumeCurrentProcess() {
        Logger.shared.log("Manual resume requested")
        if let process = processMonitor.monitoredProcess {
            Logger.shared.log("Current process state: \(process.state.rawValue)")
            if process.state == .suspended {
                processMonitor.resumeProcess(process.pid)
                Logger.shared.log("Process resumed manually")
                // Disable button immediately after clicking
                resumeButton.isEnabled = false
            }
        }
    }
    
    static func main() {
        let app = NSApplication.shared
        let delegate = MinerTimerApp()
        app.delegate = delegate
        app.run()
    }
} 