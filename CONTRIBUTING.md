# Contributing to Berry Flow

First off, thank you for considering contributing to Berry Flow! It's people like you that make this project such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed and what you expected**
- **Include logs from Tasmota console if applicable**
- **Specify your Tasmota version and device type (ESP8266/ESP32)**
- **Include your sensor model and configuration**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List any similar features in other projects if applicable**

### Pull Requests

1. Fork the repository
2. Create a new branch from `master`:
   - Features: `feature/your-feature-name`
   - Bug fixes: `bugfix/your-bugfix-name`
   - Hotfixes: `hotfix/your-hotfix-name`
3. Make your changes following our coding standards
4. Test your changes thoroughly on actual hardware if possible
5. Commit your changes with clear, descriptive commit messages
6. Push to your fork
7. Submit a pull request

## Development Setup

### Prerequisites

- Tasmota-compatible device (ESP8266/ESP32)
- Tasmota firmware v12.0.0+ with Berry support
- YF-B6 flow sensor (optional but recommended for testing)
- Basic understanding of Berry scripting language

### Testing

Before submitting a pull request:

1. **Syntax Check**: Verify Berry syntax is correct
2. **Load Test**: Load the script on a Tasmota device and verify it initializes without errors
3. **Functional Test**: If hardware is available, test actual flow detection
4. **Persistence Test**: Verify data persists across reboots
5. **MQTT Test**: Verify MQTT messages are published correctly
6. **Web Interface Test**: Check the web configuration interface works properly

### Development Workflow

1. Make your changes in small, logical commits
2. Each commit should represent a single logical change
3. Write clear commit messages in English:
   ```
   Add feature to calculate cold water flow
   
   - Implement cold water calculation as global - hot
   - Update MQTT payload to include cold water data
   - Add cold water display to web interface
   ```

4. Test your changes on real hardware when possible
5. Update documentation if your changes affect usage
6. Update CHANGELOG.md following Keep a Changelog format

## Coding Standards

### Berry Code Style

- **Indentation**: 4 spaces (no tabs)
- **Naming Conventions**:
  - Private variables: `_variable_name` (single underscore)
  - Private methods: `_method_name()` (single underscore)
  - Internal variables: `__variable` (double underscore for truly internal)
  - Public variables: `variable_name`
  - Constants: `CONSTANT_NAME`
- **Comments**: 
  - All code, comments, and documentation in **English**
  - Use `#` for single-line comments
  - Use `#- ... -#` for multi-line comments
  - Document all public methods and complex logic
- **Classes**: Use PascalCase for class names
- **Error Handling**: Always validate inputs and handle edge cases

### Example

```berry
# Single counter management class
class Counter
    var __index              # Hardware counter index (0 or 1)
    var _k_factor            # K-factor for sensor calibration
    var flow                 # Current flow rate (public)
    
    # Initialize internal variables
    def _init()
        self._k_factor = 6.6  # YF-B6 K-factor from spec
        self.flow = 0.0
    end
    
    # Public method to set K-factor with validation
    def set_k_factor(value)
        if value > 0
            self._k_factor = value
            return true
        end
        return false
    end
end
```

## Documentation Standards

When adding or modifying features, update the relevant documentation:

- **README.md**: Update if adding new features or changing usage
- **Code Comments**: Document complex algorithms and business logic
- **CHANGELOG.md**: Add entries for all user-facing changes
- **GitHub References**: Link to source code with line numbers rather than duplicating code

### Documentation Format

Follow the project's documentation structure:
- Overview section for high-level understanding
- Installation instructions for setup
- Usage examples with code snippets
- API reference linking to source code
- Configuration options with defaults

## Language Requirements

- **Communication with maintainers**: French or English
- **All code, comments, commits, documentation**: **English only**

This ensures the project remains accessible to the international open-source community.

## Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Reference issues and pull requests when applicable
- Keep first line under 72 characters
- Add detailed description in body if needed

## Review Process

1. All pull requests require review before merging
2. Maintainers may request changes or improvements
3. Be responsive to feedback and questions
4. Once approved, a maintainer will merge your PR

## Questions?

Feel free to:
- Open an issue for discussion
- Start a conversation in GitHub Discussions
- Contact the maintainers directly

Thank you for contributing to Berry Flow! 🌊
