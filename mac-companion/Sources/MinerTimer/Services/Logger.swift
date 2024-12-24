import Foundation

class Logger {
    static let shared = Logger()
    private let fileURL: URL
    private let fileHandle: FileHandle?
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("MinerTimer")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        
        fileURL = logDir.appendingPathComponent("minertimer.log")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        
        fileHandle = try? FileHandle(forWritingTo: fileURL)
        fileHandle?.seekToEndOfFile()
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
        
        print(logMessage)
    }
    
    deinit {
        fileHandle?.closeFile()
    }
} 