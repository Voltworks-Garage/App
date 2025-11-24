# Voltworks Garage Mobile App

## Project Overview

### Purpose
The Voltworks Garage mobile app is a companion application for a custom motorcycle Battery Management System (BMS) built on ESP32 hardware. The app provides real-time monitoring, configuration, and control capabilities for the motorcycle's electrical system.

### Platforms
- Android (primary target)
- iOS (secondary target)

### Communication
- **Protocol**: Bluetooth Low Energy (BLE)
- **Service Type**: UART-like bidirectional data streaming
- **Data Flow**: Real-time streaming from BMS + command/response for configuration

### Key Features
- Real-time battery monitoring (voltage, current, temperature, SOC)
- Riding dashboard with glanceable metrics
- Charging status and cell balancing visualization
- CAN bus data monitoring and diagnostics
- Secure configuration and settings management
- Password-protected administrative commands

## Technical Stack

### Framework & Language
- **Framework**: Flutter 3.10.1+
- **Language**: Dart
- **UI**: Material Design with custom motorcycle/garage theme

### Core Dependencies
- **flutter_blue_plus** (^1.32.12): BLE communication
- **provider** (^6.1.2): State management
- **permission_handler** (^11.3.1): Runtime permissions for BLE

### Additional Dependencies (to be added as needed)
- **fl_chart**: Data visualization and graphs
- **shared_preferences**: Local settings storage
- **intl**: Date/time formatting

## Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── bike_data.dart       # Battery, voltage, current, temp
│   ├── charging_status.dart # Charging state and progress
│   ├── can_data.dart        # CAN bus messages
│   └── ble_command.dart     # Command/response structures
├── services/                 # Business logic layer
│   ├── ble_service.dart     # BLE connection and communication
│   ├── data_parser.dart     # Parse incoming BLE data
│   └── command_builder.dart # Build outgoing commands
├── providers/                # State management
│   ├── ble_provider.dart    # BLE connection state
│   └── bike_data_provider.dart # Bike data state
├── screens/                  # UI screens
│   ├── home_screen.dart     # Connection & overview
│   ├── dashboard_screen.dart # Riding view
│   ├── charging_screen.dart  # Charging monitoring
│   └── data_screen.dart      # CAN bus data
├── widgets/                  # Reusable UI components
│   ├── connection_status.dart
│   ├── metric_card.dart
│   └── battery_indicator.dart
└── utils/                    # Utilities and constants
    ├── constants.dart        # BLE UUIDs, colors, etc.
    └── formatters.dart       # Data formatting helpers
```

### BLE Service Architecture

#### Connection Flow
1. **Scan**: Discover nearby BLE devices (filter by name/UUID)
2. **Connect**: Establish connection to ESP32 BMS
3. **Discover Services**: Find UART-like service and characteristics
4. **Subscribe**: Listen to notification characteristic for incoming data
5. **Communicate**: Send commands via write characteristic

#### Service Characteristics
- **TX Characteristic**: ESP32 → App (notifications)
- **RX Characteristic**: App → ESP32 (write)

#### Data Flow
```
ESP32 BMS ←→ BLE UART Service ←→ BLE Provider ←→ Data Parser ←→ Bike Data Provider ←→ UI Screens
```

### State Management Pattern
Using **Provider** pattern:
- `BleProvider`: Manages connection state, device discovery, data transmission
- `BikeDataProvider`: Stores and notifies listeners of bike metrics
- Screens consume state via `Consumer` or `Provider.of()`

## Features by Screen

### 1. Home Screen
**Purpose**: Main entry point, connection management, quick overview

**Features**:
- BLE connection status indicator
- Scan/Connect button
- List of available devices
- Quick stats summary (SOC, voltage, temperature)
- Connection history (last connected device)
- Settings access

**Layout**:
- Top: Connection status card
- Middle: Device list or quick stats (when connected)
- Bottom: Navigation bar

### 2. Dashboard Screen (Riding View)
**Purpose**: High-visibility display for viewing while riding

**Design Considerations**:
- Large, high-contrast fonts
- Minimal information density
- Critical metrics only
- Easy to read at a glance

**Metrics**:
- State of Charge (SOC) - Large circular gauge
- Battery voltage - Prominent display
- Current draw/regen - Color-coded (red=discharge, green=regen)
- Battery temperature - Warning colors if high
- Range estimate (if available)

**Layout**:
- Full-screen, portrait or landscape
- Dark theme preferred for riding
- Auto-brightness consideration

### 3. Charging Screen
**Purpose**: Monitor charging progress and cell health

**Features**:
- Charging status (idle, charging, balancing, complete)
- Overall charge progress bar
- Individual cell voltages (bar chart or list)
- Pack voltage and current
- Temperature monitoring (warn if overheating)
- Time to full charge estimate
- Cell balancing status

**Layout**:
- Top: Overall status and progress
- Middle: Cell voltage visualization
- Bottom: Temperature and time estimates

### 4. Data Screen (CAN Bus & Diagnostics)
**Purpose**: Detailed system information and diagnostics

**Features**:
- Live CAN bus message stream
- System diagnostics and errors
- Detailed battery statistics
- BMS firmware version
- Connection quality metrics
- Data logging toggle
- Export logs (future enhancement)

**Layout**:
- Tabbed interface for different data categories
- Scrollable lists/tables
- Search/filter capability

## BLE Protocol Specification

### UART-Like Service Structure

#### Service UUID
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` (Nordic UART Service - standard)
- Or custom UUID to be defined based on ESP32 implementation

#### Characteristics
- **TX Characteristic** (ESP32 → App):
  - UUID: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
  - Properties: Notify
  - Description: BMS sends data to app

- **RX Characteristic** (App → ESP32):
  - UUID: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
  - Properties: Write
  - Description: App sends commands to BMS

### Message Format

#### Incoming Data (TX)
Messages from ESP32 should follow a structured format. Suggested format:

```
<TYPE>:<DATA>\n

Examples:
SOC:85.5
VOLT:52.3
CURR:-12.4
TEMP:35.2
CELL:0,3.85,1,3.86,2,3.84,3,3.87
STATUS:CHARGING
CAN:18FF1234,8,01,02,03,04,05,06,07,08
```

Types:
- `SOC`: State of charge (%)
- `VOLT`: Pack voltage (V)
- `CURR`: Current (A, negative = discharge)
- `TEMP`: Temperature (°C)
- `CELL`: Cell index and voltage pairs
- `STATUS`: System status
- `CAN`: CAN message (ID, length, data bytes)
- `ERROR`: Error codes
- `INFO`: General information

#### Outgoing Commands (RX)
Commands from app to ESP32:

```
<COMMAND>:<PARAMETERS>\n

Examples:
AUTH:mypassword123
CONFIG:MAX_VOLT,58.8
CONFIG:MIN_VOLT,42.0
GET:STATUS
GET:CELLS
RESET:ERRORS
```

Commands:
- `AUTH`: Authenticate with password
- `CONFIG`: Set configuration parameter
- `GET`: Request specific data
- `RESET`: Reset certain states
- `CONTROL`: Control functions (future)

### Authentication Flow
1. App connects to BMS
2. App sends: `AUTH:password\n`
3. BMS responds: `AUTH:OK\n` or `AUTH:FAIL\n`
4. If OK, app can send configuration commands
5. Without auth, only read-only monitoring is available

## Phased Implementation Plan

### Phase 1: Project Setup & Foundation
**Goal**: Set up project structure and dependencies

**Tasks**:
1. Add dependencies to `pubspec.yaml`
2. Configure Android permissions (`AndroidManifest.xml`)
3. Configure iOS permissions (`Info.plist`)
4. Create folder structure (models, services, providers, screens, widgets, utils)
5. Set up app theme and constants
6. Update app name and branding

**Deliverable**: Clean project structure ready for development

### Phase 2: BLE Service Layer
**Goal**: Implement core BLE communication

**Tasks**:
1. Create `BleService` class
   - Device scanning
   - Connection management
   - Service discovery
   - Read/write/subscribe to characteristics
2. Create `BleProvider` for state management
   - Connection state
   - Device list
   - Data stream
3. Implement data parser for incoming messages
4. Implement command builder for outgoing messages
5. Add error handling and reconnection logic

**Deliverable**: Working BLE communication layer

### Phase 3: Data Models & State
**Goal**: Define data structures and state management

**Tasks**:
1. Create data models:
   - `BikeData`: SOC, voltage, current, temperature
   - `ChargingStatus`: Status, progress, cell voltages
   - `CanMessage`: CAN bus message structure
   - `BleCommand`: Command/response structures
2. Create `BikeDataProvider` for state management
3. Implement data validation and error checking

**Deliverable**: Complete data layer

### Phase 4: Navigation & Basic UI
**Goal**: Set up app navigation and basic screens

**Tasks**:
1. Create main app structure with bottom navigation
2. Implement 4 basic screen scaffolds:
   - Home
   - Dashboard
   - Charging
   - Data
3. Set up routing and navigation
4. Create common widgets (connection status, metric cards)
5. Implement app theme (colors, fonts, styles)

**Deliverable**: Navigable app with placeholder screens

### Phase 5: Screen Implementation
**Goal**: Build out complete UI for all screens

**Tasks**:
1. **Home Screen**:
   - Device scanning UI
   - Connection status display
   - Quick stats when connected
   - Settings access

2. **Dashboard Screen**:
   - Large SOC gauge
   - Voltage display
   - Current display with color coding
   - Temperature display
   - Optimize for glanceable viewing

3. **Charging Screen**:
   - Charging status indicator
   - Progress bar
   - Cell voltage visualization
   - Temperature monitoring
   - Time estimate

4. **Data Screen**:
   - CAN message list
   - System diagnostics
   - Detailed statistics
   - Log viewer

**Deliverable**: Fully functional UI for all screens

### Phase 6: Advanced Features
**Goal**: Add security, configuration, and polish

**Tasks**:
1. Implement authentication dialog
2. Create settings/configuration screen
3. Add auto-reconnect on app launch
4. Implement data persistence (last device, settings)
5. Add error notifications and user feedback
6. Optimize performance and battery usage
7. Test on physical devices
8. Polish UI/UX

**Deliverable**: Production-ready app

## Development Toolchain

### Prerequisites
- Flutter SDK 3.10.1 or higher
- Android Studio / Xcode (for platform-specific builds)
- Physical Android/iOS device (BLE doesn't work reliably in emulators)

### Setup
```bash
# Clone repository
cd c:\REPOS\Voltworks_Garage\App\voltworks_garage_app

# Install dependencies
flutter pub get

# Check Flutter setup
flutter doctor
```

### Build & Run
```bash
# Run on connected device
flutter run

# Run in debug mode with hot reload
flutter run -d <device-id>

# Build APK (Android)
flutter build apk --release

# Build iOS (requires Mac)
flutter build ios --release
```

### Testing
```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Analyze code
flutter analyze
```

### BLE Testing
- Use a BLE scanner app (nRF Connect) to verify ESP32 advertising
- Test with Nordic UART Service simulator if ESP32 not available
- Monitor BLE connection logs using platform tools

## Platform-Specific Configuration

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<!-- Add inside <manifest> tag -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to your motorcycle BMS</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to your motorcycle BMS</string>
```

## Future Enhancements

### Data Logging & History
- Local database (SQLite via `sqflite`) for historical data
- Graphs and charts showing trends over time
- Export data to CSV/JSON
- Trip logging and statistics

### Advanced Diagnostics
- Real-time CAN bus analyzer
- Error code lookup and descriptions
- Performance metrics and analytics
- Battery health tracking over time

### Configuration Management
- Profile-based settings (racing, cruising, eco)
- Remote BMS configuration
- Backup/restore settings
- Firmware version checking

### OTA Updates (Potential)
- Over-the-air firmware updates for ESP32
- Update progress monitoring
- Version management

### Notifications & Alerts
- Push notifications for critical events
- Charging complete notification
- Temperature warnings
- Low battery alerts

### Advanced UI
- Customizable dashboard layouts
- Theme options (dark/light/custom)
- Widget support (Android/iOS home screen widgets)
- Landscape mode optimization

## Notes for Development

### Best Practices
- Always test BLE on physical devices
- Handle connection drops gracefully
- Implement proper error handling for all BLE operations
- Use async/await properly for BLE operations
- Keep UI responsive during BLE operations
- Minimize BLE data transfer to conserve battery
- Cache data to reduce unnecessary BLE reads

### Common Pitfalls
- BLE permissions must be requested at runtime (Android 12+)
- Location permission required for BLE scanning on Android
- BLE operations are asynchronous - always use await
- Disconnect properly to avoid resource leaks
- Handle app lifecycle (background/foreground) for BLE connections

### Security Considerations
- Never hardcode passwords in the app
- Use secure storage for credentials if persisting
- Implement authentication timeout
- Validate all incoming data from BLE
- Consider encryption for sensitive commands (future)

## Contact & Support

**Project**: Voltworks Garage Motorcycle BMS
**Repository**: `C:\REPOS\Voltworks_Garage\App\voltworks_garage_app`
**Firmware Repository**: `C:\REPOS\Voltworks_Garage\Firmware`

---

**Document Version**: 1.0
**Last Updated**: 2025-11-22
**Status**: Planning Phase
