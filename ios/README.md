# Battery Health Monitoring System — iOS App (SwiftUI + BLE)

This folder contains SwiftUI source files for an iOS app that connects over BLE, shows a live dashboard (voltage/current/temp), and raises alerts when thresholds are exceeded.

Because `.xcodeproj` files are bulky and hard to maintain by hand, the recommended workflow is:

1. Open Xcode → **File → New → Project…**
2. Choose **iOS → App**
3. Product Name: `BHMSiOS` (or anything)
4. Interface: **SwiftUI**, Language: **Swift**
5. After creating the project, drag the `.swift` files from `ios/BHMSiOS/` into your Xcode project (check “Copy items if needed”).

## BLE module note (STM32F103)

STM32F103RB does **not** have BLE built in. You’ll need an external BLE module.

### HM-10 (default)

If you’re using **HM-10**, this iOS app supports its default BLE UART profile:

- **Service UUID**: `FFE0`
- **Characteristic UUID** (notify + write): `FFE1`

### Nordic UART Service (fallback)

Some BLE-to-UART firmwares use the **Nordic UART Service (NUS)** profile. This app also supports NUS:

- **Service UUID**: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- **TX (Notify) characteristic** (device → phone): `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX (Write) characteristic** (phone → device): `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`

If your module uses different UUIDs (or you implement your own GATT service), update the UUIDs in `BluetoothManager.swift`.

## Telemetry frame format (v1)

To keep STM32 firmware simple, v1 uses **ASCII frames** over the BLE UART notify stream.

Send one line per sample (recommended: every 1000 ms):

```
v_mV,i_mA,t_cC\n
```

Example:

```
12034,-850,2530\n
```

Where:
- `v_mV`: battery voltage in **millivolts** (integer)
- `i_mA`: battery current in **milliamps** (integer; negative allowed)
- `t_cC`: temperature in **centi-degrees C** (integer; e.g. 2530 = 25.30°C)

The app also accepts a more verbose key/value line if you prefer:

```
V=12034,I=-850,T=2530\n
```

## iOS permissions

Add these keys to your app’s `Info.plist` (Xcode will prompt if missing):

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription` (older iOS; safe to include)

