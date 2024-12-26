import Foundation
import MQTTNIO
import NIO
import Logging

class HomeAssistantClient {
    private var client: MQTTClient?
    private weak var monitor: ProcessMonitor?
    
    init() {
        setupMQTT()
    }
    
    func setMonitor(_ monitor: ProcessMonitor) {
        self.monitor = monitor
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