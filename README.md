# 🌡️ ThermalBar

**ThermalBar** is an ultra-lightweight, high-precision thermal monitoring utility for macOS. Designed for professionals who need accurate, real-time data on their hardware performance with minimal resource footprint and zero bulk.

## 🖼️ UI Showcase

| Menu Bar (Vertical) | Menu Bar (Horizontal) |
| :---: | :---: |
| ![Vertical](assets/vertical.png) | ![Horizontal](assets/horizontal.png) |

| Dashboard View | Settings & Customization |
| :---: | :---: |
| ![Dashboard](assets/dashboard.png) | ![Settings](assets/setting.png) |

## ✨ Features

- **Pro-Grade Thermal Accuracy**: Prioritizes raw hardware data from the **AppleSMC** (System Management Controller) for Performance Cores and Battery gas gauges.
- **Real-Time System Usage**: Integrated high-efficiency telemetry tracking for overall CPU load, RAM commitment (memory pressure), and GPU core utilization.
- **Customizable Menu Bar**:
  - **Temperature Section**: Choose between Vertical (TG Pro-style stacked bar) or Horizontal layout. Select Primary and Secondary metrics from CPU, GPU, Battery, or usage readings. Toggle the SF Symbol icon on/off.
  - **System Usage Section**: Display CPU, RAM, and GPU usage in the menu bar with two layouts:
    - **Vertical**: Unified stacked bar showing all selected metrics compactly in one slot.
    - **Horizontal**: Individual separated status bar items with label, mini progress bar, and percentage.
- **Dashboard**: Rich popover view with compact sensor grids and usage progress bars. Supports Vertical and Horizontal layouts for both temperature and system usage sections.
- **Temperature Alerts**: Configurable alert threshold (60–100°C) with desktop notifications. Optionally disable alerts entirely. Alerts are rate-limited to one per sensor every 5 minutes.
- **Configurable Refresh Interval**: Choose from 0.5s, 1s, 2s, 5s, or 10s polling rate to balance responsiveness and energy usage.
- **Retina-Crisp Rendering**: Custom Core Graphics drawing system using integer-aligned coordinates to ensure pixel-perfect rendering on Retina displays.
- **Intelligent Caching**: LRU `MenuBarImageCache` that reuses `NSImage` instances with theme-aware eviction on dark/light mode switch. Three separate caches for temperature, combined usage, and linear usage images.
- **Multi-Threaded Telemetry**: All hardware queries run continuously on a dedicated background serial queue at `.utility` QoS, dispatching only the final layout state to the main thread asynchronously for stutter-free performance.
- **Throttled Polling**: Slowly-changing metrics (GPU utilization, battery temperature) are queried every 3rd cycle to reduce IOKit calls without sacrificing responsiveness.
- **Apple Silicon Optimized**: Native performance on M1/M2/M3/M4 chips with zero external dependencies and an ultra-lightweight footprint.

## 🛠 Technical Implementation

ThermalBar uses a multi-layered approach to fetch hardware and system telemetry:

### Temperature Sensors
1. **AppleSMC (Primary)**: Directly queries SMC hardware registers via IOKit for the most accurate Performance Core and Battery temperatures. Reads raw SMC keys (`Tp09`, `Tp0T`, `Te0T`, `TB0T`, etc.) using the 80-byte `SMCParamStruct` IOConnectCallStructMethod protocol.
2. **HIDThermal (Secondary)**: Fallback to the macOS HID event system (`IOHIDEventSystemClient`) for supplementary thermal sensor data. Dynamically loads IOKit symbols via `dlopen`/`dlsym` to avoid compile-time linkage. Caches sensor services at startup.

### System Telemetry
- **CPU**: Direct Mach kernel processor statistics (`host_processor_info` with `PROCESSOR_CPU_LOAD_INFO`) computing delta-based utilization between successive polls. Automatic VM deallocation of previous processor arrays.
- **RAM**: Mach virtual memory query (`host_statistics64` with `HOST_VM_INFO64`) tracking wired, active, compressed, inactive, and free pages. Computes memory pressure as the ratio of non-reclaimable pages (wired + active + compressed) to total physical memory.
- **GPU**: Cached `IOAccelerator` service iterator (enumerated once at startup) querying `"PerformanceStatistics"` dictionaries for `"Device Utilization %"` or `"GPU Core Utilization"`.

### Rendering Pipeline
- Menu bar images are rendered via `NSBitmapImageRep` at 2× scale for Retina crispness, using custom `NSBezierPath` progress bars and monospaced-digit system fonts.
- Temperature images use template-mode rendering (`isTemplate = true`) for automatic dark/light mode adaptation via the system menu bar tint.
- Usage progress bars use dynamic colors with dark mode detection via `NSApp.effectiveAppearance`.

## 🚀 Getting Started

### Prerequisites
- macOS 14.0 or later
- Apple Silicon (Recommended) or Intel Mac

### Building from Source
The project is built using a custom Swift-based toolchain (no Xcode required).

```bash
# Build and sign the application
make build

# Launch the app
make run
```

### Installation
Simply drag the generated `ThermalBar.app` to your `/Applications` folder.

## ⚙️ Configuration

All settings are persisted in `UserDefaults` and accessible via the dashboard gear icon:

| Setting | Options | Default |
|---------|---------|---------|
| Primary Metric | Average CPU, GPU, Battery, CPU Usage, GPU Usage, RAM Usage | Average CPU |
| Secondary Metric | Same as above | Battery |
| Menu Bar Text Order | Horizontal, Vertical | Vertical |
| Dashboard Layout | Horizontal, Vertical | Vertical |
| Show Menu Bar Icon | Toggle | On |
| Show CPU/RAM/GPU Usage | Per-metric toggle | Off |
| Usage Layout (Menu Bar & Dashboard) | Horizontal, Vertical | Vertical |
| Refresh Interval | 0.5s, 1s, 2s, 5s, 10s | 0.5s |
| Temperature Alert Threshold | 60–100°C (step 5) | 85°C |
| Enable Temperature Alerts | Toggle | On |
| Start at Login | Toggle | Off |

## 🔏 Security & Permissions

ThermalBar requires **Code-Signing with Entitlements** to communicate with the `AppleSMC` driver. The included build system automatically applies these entitlements using an ad-hoc signature.

### Entitlements
- `com.apple.security.temporary-exception.iokit-user-client-class`: `AppleSMCClient` — required for SMC temperature reads.

## 🛡️ Privacy & Security

ThermalBar is built with a **Privacy-First** philosophy:
- **Zero Data Collection**: We do not collect, store, or transmit any data. There are no analytics, no tracking, and no "home-calling" features.
- **No Network Access**: ThermalBar does not have network entitlements and cannot connect to the internet.
- **Local Only**: All thermal readings are processed in real-time and stay entirely within your system's memory.
- **Open Source**: The full source code is available for inspection, ensuring transparency in how hardware data is handled.

## 📦 Changelog

### v0.5.0
- **Settings**: Added temperature alert threshold slider, show/hide menu bar icon toggle, 0.5s refresh interval option, notifications enable/disable toggle
- **Performance**: GPU services cached at startup (no re-enumeration per poll), battery/GPU throttled to every 3rd cycle, LRU image cache with theme-aware eviction, `DispatchSourceTimer` with `.utility` QoS
- **Rendering**: Fixed progress bar vertical centering, improved combined vertical usage layout with proper row alignment, removed magic offsets in bar positioning
- **Dashboard**: Compact grid layout for horizontal temperature view, horizontal/vertical layout pickers for both temperature and usage sections
- **Code quality**: Single source of truth for `UserDefaults` keys via `UserDefaultsKey` enum, deferred notification authorization to first alert, compile-time SMC struct size assertion, `withUnsafeBytes` for SMC data parsing, `os_log` diagnostics on HID init failures, removed dead code (`SparklineView`, `SensorData`, unused `Timer`)

### v0.4.0
- Optimized menu bar memory usage with unified image cache
- Improved rendering performance and dark mode support

### v0.3.0
- Updated showcase assets and README

### v0.2.0
- Added system usage (CPU/GPU/RAM) with advanced layout options
- Vertical and horizontal menu bar layouts

## ⚖️ License
MIT License. See [LICENSE](LICENSE) for details.
