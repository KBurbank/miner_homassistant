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
                "retain": true
            ]
            
            if type == "number" {
                // Only add these for editable number entities
                if timeValue.mqttTopic != "played_time" {
                    config["command_topic"] = timeValue.setTopic
                    config["min"] = min ?? 0
                    config["max"] = max ?? 1440
                    config["optimistic"] = false
                }
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: config),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                client.publish(
                    .string(jsonString),
                    to: "\(discoveryPrefix)/\(type)/\(deviceId)/\(timeValue.mqttTopic)/config",
                    qos: .atLeastOnce
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
        
        // Special logging for time_limit/set
        if message.topic == "minertimer/time_limit/set" {
            Logger.shared.log("\n=== Time Limit Set Message ===")
            Logger.shared.log("Topic: \(message.topic)")
            Logger.shared.log("Raw payload: \(message.payload)")
            if case .bytes(let buffer) = message.payload {
                Logger.shared.log("Bytes content: \(String(buffer: buffer))")
            }
            if case .string(let str, _) = message.payload {
                Logger.shared.log("String content: \(str)")
            }
            Logger.shared.log("Last published value: \(lastPublishedValues[baseKey] ?? -1)")
            Logger.shared.log("Current TimeScheduler value: \(timeScheduler?.currentLimit.value ?? -1)")
            Logger.shared.log("QoS: \(message.qos)")
            Logger.shared.log("Retain flag: \(message.retain)")
            Logger.shared.log("=== End Time Limit Message ===\n")
        } else {
            Logger.shared.log("\n=== Handling MQTT Message ===")
            Logger.shared.log("Topic: \(message.topic)")
        }
        
        // Parse payload
        guard let value = parsePayload(message.payload) else { return }
        
        // Skip if this is our own published value
        if lastPublishedValues[baseKey] == value {
            Logger.shared.log("Skipping our own published value for \(baseKey)")
            return
        }
        
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
        switch payload {
        case .bytes(let buffer):
            let str = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
            if let parsed = Double(str) {
                Logger.shared.log("Parsed bytes payload: \(str)")
                return parsed
            }
        case .string(let str, _):
            Logger.shared.log("Raw string payload: \(str)")
            if let parsed = Double(str) {
                return parsed
            }
        case .empty:
            Logger.shared.log("Empty payload")
        }
        Logger.shared.log("Failed to parse payload")
        return nil
    }
    
    private func publish(_ value: TimeInterval, to timeValue: TimeValue) {
        guard let client = client else {
            Logger.shared.log("❌ MQTT client not initialized")
            return
        }
        
        // Record what we're publishing
        lastPublishedValues[timeValue.baseKey ?? ""] = value
        
        let publishTopic = timeValue.stateTopic
        let message = String(format: "%.1f", value)
        Logger.shared.log("\n=== Publishing Message ===")
        Logger.shared.log("Topic: \(publishTopic)")
        Logger.shared.log("Value: \(message)")
        Logger.shared.log("Previous value: \(lastPublishedValues[timeValue.baseKey ?? ""] ?? -1)")
        Logger.shared.log("TimeValue name: \(timeValue.name)")
        Logger.shared.log("=== End Publishing ===\n")
        
        client.publish(
            .string(message),
            to: publishTopic,
            qos: .atMostOnce,
            retain: true
        ).whenComplete { result in
            switch result {
            case .success:
                Logger.shared.log("✅ Published to \(timeValue.mqttTopic)")
            case .failure(let error):
                Logger.shared.log("❌ Failed to publish to \(timeValue.mqttTopic): \(error)")
            }
        }
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
}

extension Notification.Name {
    static let weekdayLimitChanged = Notification.Name("weekdayLimitChanged")
    static let weekendLimitChanged = Notification.Name("weekendLimitChanged")
} 