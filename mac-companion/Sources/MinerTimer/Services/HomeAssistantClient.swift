import Foundation
import MQTTNIO
import NIO
import Logging

@MainActor
public class HomeAssistantClient: @unchecked Sendable {
    static let shared = HomeAssistantClient()
    private var client: MQTTClient?
    private weak var monitor: ProcessMonitor?
    private weak var timeScheduler: TimeScheduler?
    private let discoveryPrefix = "homeassistant"
    private let deviceId = "minertimer_mac"
    private var lastPublishedValues: [String: Double] = [:]
    private var lastMQTTUpdate: Date = Date()
    private let updateInterval: TimeInterval = 60
    
    private init() {
        setupMQTT()
    }
    
    func setMonitor(_ monitor: ProcessMonitor) {
        self.monitor = monitor
    }
    
    func setTimeScheduler() {
        self.timeScheduler = TimeScheduler.shared
    }
    
    private func setupMQTT() {
        Logger.shared.log("Setting up MQTT connection...")
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        let config = MQTTConfiguration(
            target: .host("homeassistant", port: 1883),
            clientId: "minertimer-mac-\(UUID().uuidString)",
            clean: true,
            credentials: MQTTConfiguration.Credentials(
                username: "mosq_user",
                password: "mosq_user_pass"
            )
        )
        
        let client = MQTTClient(
            configuration: config,
            eventLoopGroup: eventLoopGroup
        )
        
        client.connect().whenComplete { [weak self] result in
            switch result {
            case .success:
                Logger.shared.log("✅ Connected to MQTT broker")
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        // Set up message handler first
                        client.whenMessage { [weak self] message in
                            Task { @MainActor [weak self] in
                                self?.handleMessage(message)
                            }
                        }
                        
                        Logger.shared.log("Subscribing to set topics...")
                        
                        // Only subscribe to set topics
                        try await client.subscribe(
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
                Logger.shared.log("❌ Failed to connect to MQTT: \(error)")
            }
        }
        
        self.client = client
    }
    
    private func publishDiscoveryConfig() async {
        guard let client = client else { return }
        
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
                // Only add these for editable number entities. they need to be between 0 and 1440, which is 24 hours in minutes.
                if timeValue.mqttTopic != "played_time" {
                    config["command_topic"] = timeValue.setTopic
                    config["min"] = min ?? 0
                    config["max"] = max ?? 1440
                }
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: config),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                client.publish(
                    .init(
                        topic: "\(discoveryPrefix)/\(type)/\(deviceId)/\(timeValue.mqttTopic)/config",
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
    }
    
    @MainActor
    private func handleMessage(_ message: MQTTMessage) {
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
        
        // For retained messages, we'll rely on the timestamp in the payload
        // which is checked in parsePayload
        
        Logger.shared.log("Received user change from HA: \(message.topic) = \(value)")
        
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
    
    private func publish(_ value: TimeInterval, to timeValue: TimeValue) {
        guard let client = client else { return }
        
        let publishTopic = timeValue.stateTopic
        
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
    
    func publish_to_HA(_ timeValue: TimeValue) {
        publish(timeValue.value, to: timeValue)
    }
    
    @MainActor
    func subscribe_to_HA() {
        guard let timeScheduler = timeScheduler else {
            Logger.shared.log("⚠️ TimeScheduler not set")
            return
        }
        
        // Only subscribe to limit changes, not played time
        let topics = [
            timeScheduler.currentLimit.setTopic,
            timeScheduler.weekdayLimit.setTopic,
            timeScheduler.weekendLimit.setTopic
        ]
        
        for topic in topics {
            Logger.shared.log("🔔 Subscribing to \(topic)")
            client?.subscribe(to: [.init(topicFilter: topic, qos: .atMostOnce)])
        }
    }
    
    @MainActor
    func handle_message(_ topic: String, _ message: String) {
        guard let timeScheduler = timeScheduler else {
            Logger.shared.log("⚠️ TimeScheduler not set")
            return
        }
        
        guard let value = Double(message) else {
            Logger.shared.log("❌ Invalid message format: \(message)")
            return
        }
        
        // Don't handle updates to played_time
        if topic == timeScheduler.playedTime.setTopic {
            Logger.shared.log("⏭️ Ignoring played_time update from HA")
            return
        }
        
        // Handle other updates...
        if topic == timeScheduler.currentLimit.setTopic {
            timeScheduler.currentLimit.updateFromMQTT(value: value)
        } else if topic == timeScheduler.weekdayLimit.setTopic {
            timeScheduler.weekdayLimit.updateFromMQTT(value: value)
        } else if topic == timeScheduler.weekendLimit.setTopic {
            timeScheduler.weekendLimit.updateFromMQTT(value: value)
        }
    }
    
    func updatePlayedTime(_ value: TimeInterval) {
        // Only send MQTT update if enough time has passed
        let now = Date()
        guard now.timeIntervalSince(lastMQTTUpdate) >= updateInterval else {
            return
        }
        
        lastMQTTUpdate = now
        
        // Use existing publish method with TimeValue
        publish(value, to: TimeValue.create(kind: .played))
    }
}

extension Notification.Name {
    static let weekdayLimitChanged = Notification.Name("weekdayLimitChanged")
    static let weekendLimitChanged = Notification.Name("weekendLimitChanged")
} 