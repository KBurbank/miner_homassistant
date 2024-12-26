import Foundation
import CoreFoundation
import Network
import Darwin.POSIX

class HTTPServer {
    var port: UInt16 = 8456
    private var socket: CFSocket?
    private var handleCallback: ((String) -> Void)?
    
    init(callback: @escaping (String) -> Void) {
        self.handleCallback = callback
    }
    
    func start() throws {
        var sin = sockaddr_in()
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_port = port.bigEndian
        sin.sin_addr.s_addr = INADDR_ANY.bigEndian
        sin.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        
        var context = CFSocketContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, CFSocketCallBackType.acceptCallBack.rawValue, { socket, type, address, data, info in
            let server = Unmanaged<HTTPServer>.fromOpaque(info!).takeUnretainedValue()
            server.handleConnection(data?.assumingMemoryBound(to: CFSocketNativeHandle.self).pointee ?? -1)
        }, &context)
        
        guard let socket = socket else { 
            Logger.shared.log("❌ Failed to create socket")
            throw NSError(domain: "Socket creation failed", code: -1) 
        }
        
        // Set socket options
        var yes: Int32 = 1
        let sockfd = CFSocketGetNative(socket)
        
        // Enable address reuse
        if setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, UInt32(MemoryLayout<Int32>.size)) != 0 {
            Logger.shared.log("❌ Failed to set SO_REUSEADDR")
        }
        
        // Enable port reuse
        if setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT, &yes, UInt32(MemoryLayout<Int32>.size)) != 0 {
            Logger.shared.log("❌ Failed to set SO_REUSEPORT")
        }
        
        // Try to bind multiple times
        var bindSuccess = false
        for attempt in 1...3 {
            Logger.shared.log("Binding attempt \(attempt)...")
            let data = Data(bytes: &sin, count: MemoryLayout<sockaddr_in>.size)
            if CFSocketSetAddress(socket, data as CFData) == .success {
                bindSuccess = true
                break
            }
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        if !bindSuccess {
            Logger.shared.log("❌ Failed to bind after multiple attempts")
            throw NSError(domain: "Failed to bind to port", code: -1)
        }
        
        Logger.shared.log("✅ Server bound to port \(port)")
    }
    
    private func handleConnection(_ sock: CFSocketNativeHandle) {
        Logger.shared.log("Received connection on local server")
        
        // Read HTTP request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(sock, &buffer, buffer.count, 0)
        
        if bytesRead > 0 {
            if let request = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) {
                Logger.shared.log("Received request: \(request.split(separator: "\n").first ?? "")")
                
                if request.contains("GET /callback") {
                    // Extract URL from request
                    if let urlStart = request.range(of: "GET ")?.upperBound,
                       let urlEnd = request[urlStart...].range(of: " HTTP")?.lowerBound {
                        let url = String(request[urlStart..<urlEnd])
                        Logger.shared.log("Extracted callback URL: \(url)")
                        handleCallback?(url)
                    } else {
                        Logger.shared.log("❌ Failed to extract callback URL from request")
                    }
                    
                    // Send response
                    let response = """
                    HTTP/1.1 200 OK
                    Content-Type: text/html
                    
                    <html><body><h1>Authentication successful!</h1><p>You can close this window.</p></body></html>
                    """
                    send(sock, response, response.count, 0)
                    Logger.shared.log("Sent success response to browser")
                }
            }
        }
        
        close(sock)
    }
    
    func stop() {
        if let socket = socket {
            CFSocketInvalidate(socket)
        }
        socket = nil
    }
} 