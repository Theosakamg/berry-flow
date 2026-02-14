# Berry Flow - Water Counter Management for Tasmota

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A comprehensive water flow monitoring solution for Tasmota devices using the Berry scripting language. Designed for YF-B6 flow sensors, this project provides real-time flow rate monitoring, accumulated volume tracking, and MQTT integration for home automation systems.

## Features

- **Dual Counter Support**: Monitor both global (hot + cold) and hot water separately
- **Real-Time Flow Monitoring**: Calculate flow rates in L/min using YF-B6 sensor specifications (Q[L/min] = f[Hz] / 6.6)
- **Persistent Storage**: Automatic saving and restoration of counter values across reboots
- **MQTT Integration**: Publish flow data to MQTT for integration with Home Assistant and other platforms
- **Web Interface**: Built-in configuration and monitoring interface
- **Calibration Support**: Adjustable K-factor and offset calibration for accurate measurements
- **Debounce Configuration**: Optimized pulse counting with configurable debounce timing

## Hardware Requirements

- Tasmota-compatible device (ESP8266/ESP32)
- YF-B6 water flow sensor(s) - up to 2 sensors
- Tasmota firmware with Berry support (v12.0.0+)

## Installation

1. Ensure your Tasmota device has Berry scripting support enabled
2. Copy [`water_counter.be`](src/water_counter.be) to your Tasmota filesystem
3. Load the script via Tasmota console: `br load("water_counter.be")`
4. The module will auto-initialize and register with Tasmota

### Manual Installation via Tasmota Web Interface

1. Navigate to **Consoles** → **Manage File system**
2. Upload `water_counter.be`
3. Edit `autoexec.be` (or create it) and add:
```berry
load('water_counter.be')
```
4. Restart your device

## Configuration

### Hardware Counter Setup

Configure your GPIO pins as counters in Tasmota:
```
GPIO configuration → Counter1 (for global)
GPIO configuration → Counter2 (for hot water)
```

### Web Interface

Access the web configuration interface at: `http://<device-ip>/wc_config`

Configure:
- **K-Factor**: Calibration factor for flow calculation (default: 6.6 for YF-B6)
- **Offset**: Initial offset for total volume calibration
- **Debounce**: Pulse counting debounce time in milliseconds (default: 3ms)

### MQTT Topic

Data is published to: `tele/<device-topic>/SENSOR`

Example payload:
```json
{
  "WaterCounter": {
    "Global": {
      "Total": 1234.56,
      "Flow": 12.5
    },
    "Hot": {
      "Total": 456.78,
      "Flow": 5.2
    },
    "Cold": {
      "Total": 777.78,
      "Flow": 7.3
    },
    "LastUse": "2026-02-14T10:30:00",
    "FlowDuration": 120
  }
}
```

## Technical Specifications

### YF-B6 Sensor

- **Formula**: Q[L/min] = f[Hz] / 6.6
- **Maximum Flow**: ~30 L/min
- **Pulse Frequency**: ~198 Hz at max flow (one pulse every ~5ms)
- **Recommended Debounce**: 3ms (must be < 5ms for accurate counting)

### Sampling Rate

The system samples at **100ms intervals** (10 Hz), matching the original Tasmota script implementation for consistent flow calculations.

## Usage

### Reading Values

Values are automatically published to MQTT and displayed on the device's web interface.

### Resetting Counters

Via Tasmota console:
```berry
# Reset global counter
gpio.counter_set(0, 0)

# Reset hot water counter
gpio.counter_set(1, 0)
```

Or use the web interface reset buttons.

### Calibration

1. Set a known volume offset via web interface
2. Adjust K-factor if your sensor differs from YF-B6 specifications
3. Changes are persisted automatically

## Architecture

The project implements an object-oriented design with two main classes:

- **Counter**: Manages individual counter state, calculations, and persistence
- **WaterCounter**: Orchestrates multiple counters, MQTT publishing, and web interface

See the [source code](src/water_counter.be) for detailed implementation.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Migration from Tasmota Script

This Berry implementation replaces the legacy Tasmota scripting version with improved:
- Object-oriented design for better maintainability
- Proper persistence handling
- Enhanced MQTT integration
- Modern web interface capabilities

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/Theosakamg/berry-flow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Theosakamg/berry-flow/discussions)

## Acknowledgments

- Tasmota development team for Berry scripting support
- Original Tasmota script implementation that inspired this project
