# Berry Script Validation

This repository uses GitHub Actions to automatically validate all Berry scripts for syntax correctness.

## How It Works

The validation workflow:

1. **Triggers on**:
   - Push to `master` or `main` branches
   - Pull requests targeting `master` or `main`
   - Only when `.be` files in `src/` are modified or the workflow itself changes

2. **Validation Process**:
   - Clones the official Berry compiler (v1.1.0) from [berry-lang/berry](https://github.com/berry-lang/berry)
   - Compiles the Berry interpreter
   - Concatenates Tasmota API stubs (`.github/tasmota_stubs.be`) with each script for validation
   - Uses Berry's `-c` flag to compile the combined file to bytecode, validating syntax
   - Reports any syntax errors as build failures

3. **Caching**:
   - The Berry compiler is cached between runs to speed up validation
   - Cache key: `berry-compiler-{OS}-v1.1.0`

## Running Locally

To validate Berry scripts on your local machine:

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install build-essential libreadline-dev git

# Clone and build Berry
git clone --depth 1 --branch v1.1.0 https://github.com/berry-lang/berry.git
cd berry
make

# Validate the script (from your project root)
cat .github/tasmota_stubs.be src/water_counter.be > /tmp/validate_combined.be
./berry -c /tmp/validate_combined.be
```

For macOS:
```bash
brew install readline
git clone --depth 1 --branch v1.1.0 https://github.com/berry-lang/berry.git
cd berry
make

# Validate the script (from your project root)
cat .github/tasmota_stubs.be src/water_counter.be > /tmp/validate_combined.be
./berry -c /tmp/validate_combined.be
```

## Tasmota API Stubs

Since Berry scripts use Tasmota-specific modules (`gpio`, `persist`, `mqtt`, `webserver`, `tasmota`), the validation workflow uses API stubs defined in `.github/tasmota_stubs.be`. These stubs provide:

- Module and function signatures without implementation
- Allows syntax validation without requiring actual Tasmota runtime
- Covers all Tasmota APIs used by `water_counter.be`

The stubs are concatenated with each script before compilation, making all Tasmota APIs available in the compilation context.

## Syntax Validation vs Runtime Testing

**Important**: This workflow only validates **syntax correctness**. It does not:
- Execute the scripts
- Test runtime behavior
- Verify Tasmota-specific API correctness (only stubs are used)
- Check for logic errors

For complete testing, deploy scripts to an actual Tasmota device.

## Workflow Status

[![Berry Script Validation](https://github.com/Theosakamg/berry-flow/actions/workflows/berry-validation.yml/badge.svg)](https://github.com/Theosakamg/berry-flow/actions/workflows/berry-validation.yml)

Green badge = All scripts have valid syntax ✓

## References

- [Berry Language Documentation](https://berry.readthedocs.io/)
- [Berry GitHub Repository](https://github.com/berry-lang/berry)
- [Berry EBNF Grammar](https://github.com/berry-lang/berry/blob/master/tools/grammar/berry.ebnf)
