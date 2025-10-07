# Changelog

## watchOS and MiaoMiao 2 Compatibility Updates

### Overview
This update improves compatibility with the latest watchOS versions and explicitly documents MiaoMiao 2 transmitter support.

### Changes Made

#### 1. Documentation Updates
- **README.md**: Updated to explicitly mention MiaoMiao 2 support
- Added "Supported Transmitters" section listing:
  - Abbott Libre 2 / 3 (direct BLE connection)
  - MiaoMiao and MiaoMiao 2
  - Bubble
  - BluCon

#### 2. watchOS Extended Runtime Session Improvements
**File**: `DiaBLE Watch Extension/MainDelegate.swift`

- **Enhanced session lifecycle management**: Added proper state checking before starting new extended runtime sessions
- **Session validation**: Only schedule sessions if the calculated date is in the future
- **Session cleanup**: Invalidate existing sessions before starting new ones to prevent conflicts
- **Improved delegate methods**: Added better error handling and logging for session state transitions
- **Support for session invalidation reasons**: Handle `resigned`, `expired`, and unknown reasons appropriately

These changes ensure that the Apple Watch app can maintain background connections more reliably with the latest watchOS versions.

#### 3. Bluetooth State Restoration
**File**: `DiaBLE/BluetoothDelegate.swift`

- **Comprehensive state restoration**: Implemented full handling of Bluetooth state restoration for background sessions
- **Peripheral restoration**: Automatically reconnect to previously connected devices when the app is terminated and relaunched by the system
- **Device type detection**: Properly identify and recreate device objects (Abbott, BluCon, Bubble, MiaoMiao) during state restoration
- **Service rediscovery**: Re-establish characteristics after state restoration

This is crucial for watchOS where the system may terminate the app to save battery, but needs to restore Bluetooth connections when data is available.

#### 4. watchOS Background Modes
**File**: `DiaBLE Watch Extension/Info.plist`

- **Removed incorrect UIBackgroundModes**: Removed iOS-specific `audio` background mode
- **Added self-care mode**: Added `self-care` to WKBackgroundModes for better health monitoring support
- **Maintained existing modes**: Kept `alarm` and `workout-processing` for comprehensive background operation

These changes align with Apple's latest guidelines for health and fitness apps on watchOS.

#### 5. MiaoMiao Device Detection
**File**: `DiaBLE/Devices/MiaoMiao.swift`

- **Case-insensitive matching**: Improved device name detection to handle various naming conventions (MiaoMiao, miaomiao, MIAOMIAO, etc.)
- **MiaoMiao 2 detection**: Enhanced detection for MiaoMiao 2 devices
- **Future-proofing**: Added support for potential MiaoMiao 3 devices

### Technical Details

#### Extended Runtime Sessions
Extended runtime sessions allow the Apple Watch app to continue running in the background to maintain Bluetooth connections and receive glucose readings. The improvements ensure:
- Sessions are only scheduled when valid
- Old sessions are properly cleaned up
- State transitions are properly logged for debugging

#### State Restoration
When the watchOS system terminates the app to conserve battery, it can later restore the app's state when Bluetooth data arrives. The restoration improvements ensure:
- Previously connected devices are automatically reconnected
- Device types are correctly identified
- Services and characteristics are rediscovered
- The user doesn't need to manually reconnect

#### Background Modes
The `self-care` background mode is specifically designed for health-related apps on watchOS and provides better support for continuous glucose monitoring applications.

### Compatibility
- **Minimum watchOS version**: 11.0
- **Minimum iOS version**: 15.0
- **Supported devices**: All MiaoMiao variants (1, 2, 3), Bubble, BluCon, Abbott Libre 2/3

### Testing Recommendations
1. Test connection with MiaoMiao 2 device
2. Verify background connectivity on watchOS
3. Test state restoration by forcing app termination
4. Verify extended runtime sessions work correctly
5. Ensure glucose readings continue in background

### Known Issues
None at this time. If you encounter issues with MiaoMiao 2 connectivity or watchOS background operation, please open an issue with:
- watchOS version
- Device type (MiaoMiao 1/2/3, etc.)
- Steps to reproduce
- Console logs (if available)
