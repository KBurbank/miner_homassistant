import Foundation

class Logger {
    static let shared = Logger()
    private let logFile: URL
    private let fileHandle: FileHandle?
    
    private lazy var dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let minerTimerDir = appSupport.appendingPathComponent("MinerTimer")
        
        try? FileManager.default.createDirectory(at: minerTimerDir, withIntermediateDirectories: true)
        
        logFile = minerTimerDir.appendingPathComponent("minertimer.log")
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        
        // Open file handle for appending
        fileHandle = try? FileHandle(forWritingTo: logFile)
        fileHandle?.seekToEndOfFile()
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        print(logMessage, terminator: "")  // Console output
        
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    func getLogPath() -> String {
        return logFile.path
    }
} 