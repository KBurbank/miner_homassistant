import Foundation
import MQTTNIO
import NIO
import Logging

@MainActor
public class HomeAssistantClient: @unchecked Sendable {
    private var client: MQTTClient?
    private weak var timeScheduler: TimeScheduler?
    private let discoveryPrefix = "homeassistant"
    private let deviceId = "minertimer_mac"
    private var lastPublishedValues: [String: Double] = [:]
    private var lastMQTTUpdate: Date = Date()
    private let updateInterval: TimeInterval = 60
    private var isConnected = false
    private var eventLoopGroup: EventLoopGroup?
    private var config: MQTTConfig
    
    init(config: MQTTConfig = MQTTConfig.load()) {
        self.config = config
        if config.isEnabled {
            setupMQTT()
        }
    }
    
    func setTimeScheduler(_ scheduler: TimeScheduler) {
        self.timeScheduler = scheduler
    }
    
    func updateConfig(_ newConfig: MQTTConfig) {
        config = newConfig
        
        // Disconnect if MQTT is disabled
        if !config.isEnabled {
            client?.disconnect()
            client = nil
            isConnected = false
            try? eventLoopGroup?.syncShutdownGracefully()
            eventLoopGroup = nil
            return
        }
        
        // Reconnect with new settings if MQTT is enabled
        client?.disconnect()
        setupMQTT()
    }
    
    private func setupMQTT() {
        guard config.isEnabled else { return }
        
        Logger.shared.log("Setting up MQTT connection...")
        
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        let host = config.host
        let port = config.port
        let useAuth = config.useAuthentication
        let username = config.username
        let password = config.password
        
        var mqttConfig = MQTTConfiguration(
            target: .host(host, port: port),
            clientId: "minertimer-mac-\(UUID().uuidString)",
            clean: true,
            keepAliveInterval: .seconds(30),
            connectionTimeoutInterval: .seconds(10)
        )
        
        if useAuth {
            mqttConfig.credentials = MQTTConfiguration.Credentials(
                username: username,
                password: password
            )
        }
        
        guard let eventLoopGroup = eventLoopGroup else { return }
        
        let client = MQTTClient(
            configuration: mqttConfig,
            eventLoopGroup: eventLoopGroup
        )
        
        // Set up connection status monitoring
        client.whenConnected { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isConnected = true
                Logger.shared.log("✅ MQTT Connected to \(host):\(port)")
            }
        }
        
        client.whenDisconnected { [weak self] reason in
            Task { @MainActor [weak self] in
                self?.isConnected = false
                Logger.shared.log("❌ MQTT Disconnected from \(host): \(reason)")
                // Try to reconnect after a delay
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                self?.reconnect()
            }
        }
        
        self.client = client
        connect()
    }
    
    private func connect() {
        guard config.isEnabled else { return }
        
        let host = config.host
        let port = config.port
        
        Logger.shared.log("🔄 Connecting to MQTT at \(host):\(port)...")
        
        client?.connect().whenComplete { [weak self] result in
            switch result {
            case .success:
                Logger.shared.log("✅ Connected to MQTT broker")
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        // Set up message handler first
                        client?.whenMessage { [weak self] message in
                            Task { @MainActor [weak self] in
                                self?.handleMessage(message)
                            }
                        }
                        
                        Logger.shared.log("Subscribing to set topics...")
                        
                        // Only subscribe to set topics
                        try await client?.subscribe(
                            to: [
                                .init(topicFilter: "minertimer/+/set", qos: .atMostOnce)
                            ]
                        )
                        
                        // Publish discovery config
                        await self.publishDiscoveryConfig()
                        
                        Logger.shared.log("=== MQTT Setup Complete ===")
                        
                    } catch {
                        Logger.shared.log("❌ Error during MQTT setup: \(error)")
                    }
                }
                
            case .failure(let error):
                Logger.shared.log("❌ Failed to connect to MQTT at \(host): \(error)")
                // Try to reconnect after a delay
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    self?.reconnect()
                }
            }
        }
    }
    
    private func reconnect() {
        guard config.isEnabled else { return }
        
        Logger.shared.log("🔄 Attempting to reconnect to MQTT...")
        connect()
    }
    
    deinit {
        client?.disconnect()
        try? eventLoopGroup?.syncShutdownGracefully()
    }
    
    private func publishDiscoveryConfig() async {
        guard let client = client, isConnected, config.isEnabled else {
            Logger.shared.log("❌ Cannot publish discovery config: not connected")
            return
        }
        
        Logger.shared.log("📢 Publishing MQTT discovery config...")
        
        // Common device config
        let deviceConfig: [String: Any] = [
            "identifiers": [deviceId],
            "name": "MinerTimer Mac",
            "model": "Mac Companion",
            "manufacturer": "MinerTimer"
        ]
        
        // Helper function to create and publish config
        func publishEntityConfig(name: String, timeValue: TimeValue, type: String = "number", min: Int? = nil, max: Int? = nil) {
            var config: [String: Any] = [
                "name": "Minecraft \(name)",
                "unique_id": "minertimer_\(timeValue.mqttTopic)",
                "state_topic": timeValue.stateTopic,
                "unit_of_measurement": "minutes",
                "device": deviceConfig,
                "retain": false,
                "optimistic": true
            ]
            
            if type == "number" {
                // Only add these for editable number entities
                if timeValue.mqttTopic != "played_time" {
                    config["command_topic"] = timeValue.setTopic
                    config["min"] = min ?? 0
                    config["max"] = max ?? 1440  // 24 hours in minutes
                }
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: config),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let topic = "\(discoveryPrefix)/\(type)/\(deviceId)/\(timeValue.mqttTopic)/config"
                Logger.shared.log("📢 Publishing config to \(topic)")
                client.publish(
                    .init(
                        topic: topic,
                        payload: .string(jsonString),
                        qos: .atLeastOnce,
                        retain: true
                    )
                )
            }
        }
        
        // Publish all configs using TimeValue.create
        publishEntityConfig(name: "Time Limit", timeValue: TimeValue.create(kind: .current))
        publishEntityConfig(name: "Weekday Limit", timeValue: TimeValue.create(kind: .weekday))
        publishEntityConfig(name: "Weekend Limit", timeValue: TimeValue.create(kind: .weekend))
        publishEntityConfig(name: "Played Time", timeValue: TimeValue.create(kind: .played), type: "sensor")
        
        Logger.shared.log("✅ Discovery config published")
    }
    
    @MainActor
    private func handleMessage(_ message: MQTTMessage) {
        Logger.shared.log("📥 Received MQTT message: \(message.topic)")
        
        // Extract baseKey from topic
        let components = message.topic.split(separator: "/")
        guard components.count >= 3 else { return }
        let baseKey = String(components[1])
        
        // Skip played_time silently
        if baseKey == "played_time" { return }
        
        // Parse payload
        guard let value = parsePayload(message.payload) else { return }
        
        // Only process messages from /set topic (user changes in HA)
        if !message.topic.hasSuffix("/set") {
            return
        }
        
        Logger.shared.log("📝 Received user change from HA: \(message.topic) = \(value)")
        
        // Find matching kind from baseKey
        guard let kind = TimeValueKind.allCases.first(where: { 
            $0.config.baseKey == baseKey 
        }) else {
            return
        }
        
        // Get the existing TimeValue from timeScheduler
        guard let timeScheduler = timeScheduler else { return }
        
        let timeValue: TimeValue?
        switch kind {
        case .current: 
            timeValue = timeScheduler.currentLimit
        case .weekday:
            timeValue = timeScheduler.weekdayLimit
        case .weekend:
            timeValue = timeScheduler.weekendLimit
        case .played:
            timeValue = timeScheduler.playedTime
        case .timeRequest:
            timeValue = nil
        }
        
        guard let timeValue else { return }
        
        // Update the existing TimeValue
        timeValue.updateFromMQTT(value: value)
    }
    
    private func parsePayload(_ payload: MQTTPayload) -> Double? {
        // Get string from payload
        let str: String
        switch payload {
        case .bytes(let buffer):
            str = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
        case .string(let s, _):
            str = s
        case .empty:
            return nil
        }
        
        // Try parsing as JSON first
        if let data = str.data(using: .utf8),
           let json = try? JSONDecoder().decode([String: Double].self, from: data),
           let value = json["value"],
           let timestamp = json["timestamp"] {
            
            // Check if message is from before midnight
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            let midnight = calendar.startOfDay(for: Date())
            let messageDate = Date(timeIntervalSince1970: timestamp)
            
            if messageDate < midnight {
                Logger.shared.log("⏭️ Ignoring message from before midnight")
                return nil
            }
            
            return value
        }
        
        // Fallback to direct number parsing
        return Double(str)
    }
    
    func publish_to_HA(_ timeValue: TimeValue) {
        guard isConnected, config.isEnabled else {
            Logger.shared.log("❌ Cannot publish: MQTT not enabled or not connected")
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastMQTTUpdate) >= updateInterval {
            publish(timeValue.value, to: timeValue)
            lastMQTTUpdate = now
        }
    }
    
    private func publish(_ value: TimeInterval, to timeValue: TimeValue) {
        guard let client = client, isConnected, config.isEnabled else {
            Logger.shared.log("❌ Cannot publish: MQTT not enabled or not connected")
            return
        }
        
        let publishTopic = timeValue.stateTopic
        Logger.shared.log("📤 Publishing to \(publishTopic): \(value)")
        
        // Send numeric value with timestamp in properties
        client.publish(
            .init(
                topic: publishTopic,
                payload: .string(String(format: "%.2f", value)),  // Format to 2 decimal places
                qos: .atMostOnce,
                retain: false,
                properties: .init(
                    userProperties: [
                        MQTTUserProperty(
                            name: "timestamp",
                            value: String(Date().timeIntervalSince1970)
                        )
                    ]
                )
            )
        )
    }
}

extension Notification.Name {
    static let weekdayLimitChanged = Notification.Name("weekdayLimitChanged")
    static let weekendLimitChanged = Notification.Name("weekendLimitChanged")
} 