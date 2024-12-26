import Foundation
import MQTTNIO
import NIO
import Logging

class HomeAssistantClient {
    private var client: MQTTClient?
    private weak var monitor: ProcessMonitor?
    private let discoveryPrefix = "homeassistant"
    private let deviceId = "minertimer_mac"
    
    init() {
        setupMQTT()
    }
    
    func setMonitor(_ monitor: ProcessMonitor) {
        self.monitor = monitor
    }
    
    private func publishDiscoveryConfig() {
        guard let client = client else { return }
        
        // Create discovery config for time limit number entity
        let timeLimitConfig: [String: Any] = [
            "name": "Minecraft Time Limit",
            "unique_id": "minertimer_time_limit",
            "state_topic": "minertimer/time_limit/state",
            "command_topic": "minertimer/time_limit/set",
            "unit_of_measurement": "minutes",
            "min": 0,
            "max": 1440,
            "device": [
                "identifiers": [deviceId],
                "name": "MinerTimer Mac",
                "model": "Mac Companion",
                "manufacturer": "MinerTimer"
            ]
        ]
        
        // Convert config to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: timeLimitConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // Publish discovery config
            client.publish(
                .string(jsonString),
                to: "\(discoveryPrefix)/number/\(deviceId)/time_limit/config",
                qos: .atLeastOnce,
                retain: true
            ).whenComplete { result in
                switch result {
                case .success:
                    Logger.shared.log("✅ Published discovery config")
                case .failure(let error):
                    Logger.shared.log("❌ Failed to publish discovery config: \(error)")
                }
            }
        }
        
        // Similarly for played time sensor
        let playedTimeConfig: [String: Any] = [
            "name": "Minecraft Played Time",
            "unique_id": "minertimer_played_time",
            "state_topic": "minertimer/played_time",
            "unit_of_measurement": "minutes",
            "device": [
                "identifiers": [deviceId],
                "name": "MinerTimer Mac",
                "model": "Mac Companion",
                "manufacturer": "MinerTimer"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: playedTimeConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            client.publish(
                .string(jsonString),
                to: "\(discoveryPrefix)/sensor/\(deviceId)/played_time/config",
                qos: .atLeastOnce,
                retain: true
            ).whenComplete { result in
                switch result {
                case .success:
                    Logger.shared.log("✅ Published played time discovery config")
                case .failure(let error):
                    Logger.shared.log("❌ Failed to publish played time discovery config: \(error)")
                }
            }
        }
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
        
        // Connect to broker
        client.connect().whenComplete { result in
            switch result {
            case .success:
                Logger.shared.log("✅ Connected to MQTT broker")
                self.subscribeToTopics(client)
                self.publishDiscoveryConfig()  // Publish discovery config
                
                // Publish initial time limit
                if let monitor = self.monitor {
                    self.updateTimeLimit(monitor.currentLimit)
                }
                
            case .failure(let error):
                Logger.shared.log("❌ Failed to connect to MQTT: \(error)")
            }
        }
        
        self.client = client
    }
    
    private func subscribeToTopics(_ client: MQTTClient) {
        client.subscribe(
            to: [
                .init(topicFilter: "minertimer/time_limit/set", qos: .atMostOnce)
            ]
        ).whenComplete { result in
            switch result {
            case .success:
                Logger.shared.log("✅ Subscribed to time limit topic")
                
                // Set up message handler
                client.whenMessage { [weak self] message in
                    Logger.shared.log("Received MQTT message on topic: \(message.topic)")
                    
                    if message.topic == "minertimer/time_limit/set",
                       case .bytes(let buffer) = message.payload {
                        let payload = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes)
                        if let payload = payload,
                           let limit = Double(payload) {
                            Logger.shared.log("Received new time limit: \(limit)")
                            Task { @MainActor in
                                self?.monitor?.updateTimeLimit(limit)
                            }
                        }
                    }
                }
            case .failure(let error):
                Logger.shared.log("❌ Failed to subscribe: \(error)")
            }
        }
    }
    
    func updatePlayedTime(_ time: TimeInterval) {
        guard let client = client else {
            Logger.shared.log("❌ MQTT client not initialized")
            return
        }
        
        let message = String(format: "%.1f", time)
        Logger.shared.log("Publishing played time: \(message)")
        
        client.publish(
            .string(message),
            to: "minertimer/played_time",
            qos: .atMostOnce
        ).whenComplete { result in
            switch result {
            case .success:
                Logger.shared.log("✅ Published played time")
            case .failure(let error):
                Logger.shared.log("❌ Failed to publish: \(error)")
            }
        }
    }
    
    func updateTimeLimit(_ limit: TimeInterval) {
        guard let client = client else {
            Logger.shared.log("❌ MQTT client not initialized")
            return
        }
        
        let message = String(format: "%.1f", limit)
        Logger.shared.log("Publishing new time limit: \(message)")
        
        client.publish(
            .string(message),
            to: "minertimer/time_limit/state",
            qos: .atMostOnce
        ).whenComplete { result in
            switch result {
            case .success:
                Logger.shared.log("✅ Published new time limit")
            case .failure(let error):
                Logger.shared.log("❌ Failed to publish time limit: \(error)")
            }
        }
    }
} 