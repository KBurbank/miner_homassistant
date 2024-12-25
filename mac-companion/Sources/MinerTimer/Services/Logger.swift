import Foundation

class Logger {
    static let shared = Logger()
    private let dateFormatter: DateFormatter
    private let serviceMode: Bool
    private let logFile: URL?
    private let errorFile: URL?
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy 'at' h:mm:ss a"
        serviceMode = CommandLine.arguments.contains("--service")
        
        if serviceMode {
            logFile = URL(fileURLWithPath: "/Users/Shared/minertimer/service.log")
            errorFile = URL(fileURLWithPath: "/Users/Shared/minertimer/service.error.log")
        } else {
            logFile = nil
            errorFile = nil
        }
    }
    
    func log(_ message: String, isError: Bool = false) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if serviceMode {
            // Write to file in service mode
            let fileURL = isError ? errorFile : logFile
            if let fileURL = fileURL {
                do {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(logMessage.data(using: .utf8)!)
                        handle.closeFile()
                    } else {
                        try logMessage.write(to: fileURL, atomically: true, encoding: .utf8)
                    }
                } catch {
                    print("Error writing to log file: \(error)")
                }
            }
        } else {
            // Print to console in GUI mode
            print(logMessage, terminator: "")
        }
    }
    
    func error(_ message: String) {
        log(message, isError: true)
    }
} 