# Refactoring Changes

## MQTT Configuration Changes (2024-01-09)

### MQTT Configuration UI
- Created a new settings section for MQTT integration
- Added toggle for enabling/disabling MQTT
- Added configuration button that opens a sheet
- Made the window more compact and properly laid out

### MQTT Configuration Model
- Created `MQTTConfig` class to store settings
- Added persistence using UserDefaults
- Set default values to match previous hardcoded settings:
  ```swift
  host: "homeassistant"
  port: 1883
  useAuthentication: true
  username: "mosq_user"
  password: "mosq_user_pass"
  ```

### Text Field Improvements
- Created custom `EditableNSTextField` and `EditableNSSecureTextField` classes
- Added support for standard text editing operations without requiring an Edit menu:
  - Command-C: Copy
  - Command-V: Paste
  - Command-X: Cut
  - Command-A: Select All
  - Command-Z: Undo
  - Command-Shift-Z: Redo

### State Management
- Created `SettingsState` class to properly handle MQTT configuration state
- Used `@ObservedObject` for proper SwiftUI state management
- Ensured settings are saved and applied immediately when changed

### HomeAssistant Integration
- Updated `HomeAssistantClient` to use the new MQTT configuration
- Added proper connection handling based on enabled state
- Improved error logging and reconnection logic 