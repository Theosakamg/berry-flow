# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0]

### Added
- Initial changelog to track future releases
- Contributor Covenant Code of Conduct reference
- GitHub templates for bug reports, feature requests, and pull requests
- Hardware offset tracking (`_hw_offset`, `_raw_counter_last`) to maintain monotonic counter totals across device reboots
- Configuration exposure in web UI: offsets, K-factors, debounce values
- Configuration data in MQTT payloads for better visibility and debugging
- Warning logs when negative counter deltas are detected
- `get_offset()` getter method for Counter class
- GitHub Actions workflow for automatic Berry script syntax validation
- Tasmota API stubs (`.github/tasmota_stubs.be`) for syntax validation without runtime
- CI/CD badge in README showing validation status
- Validation documentation (`.github/VALIDATION.md`)

### Changed
- Persistence strategy: now saves immediately after each flow stop instead of only daily saves
- Counter synchronization: aligns both pulse counts and liter values when hardware counter jumps ahead
- Configuration fragment caching: built once and cached instead of recalculating on every MQTT publish
- README updated with monotonic counter features, Config in MQTT payload, and persistence strategy details

### Fixed
- Water counter totals no longer decrease after device reboots due to Tasmota Counter RAM persistence lag
- Liter accumulation stays synchronized with pulse counts when hardware counter advances

### Pending
- Additional module documentation

## [0.0.0] - 2026-02-14

### Added
- `water_counter.be` Berry implementation for dual water flow counters
- Legacy Tasmota script reference
- Essential documentation: README, CONTRIBUTING, LICENSE
- Project configuration files: `.editorconfig`, `.gitignore`
- Contributor Covenant Code of Conduct (this release)

---

Links:
- [Unreleased]: https://github.com/Theosakamg/berry-flow/compare/master...HEAD
- [0.1.0]: https://github.com/Theosakamg/berry-flow/releases/tag/v0.1.0 (to be created)
