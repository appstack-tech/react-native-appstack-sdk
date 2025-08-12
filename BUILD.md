# Build Documentation

Simple build system for the React Native Appstack SDK.

## Quick Start

```bash
# Local development
npm run build

# Clean build
npm run build:clean

# CI/CD 
./build.sh --ci
```

## Build Script

Single `build.sh` script handles all scenarios:

**Options**:
- `--clean` - Remove previous builds
- `--ci` - CI mode (uses npm ci, runs tests)

**Examples**:
```bash
./build.sh           # Basic build
./build.sh --clean   # Clean build  
./build.sh --ci      # CI build with tests
```

## GitHub Actions

Simple workflow in `.github/workflows/build.yml`:

- **Build**: Tests and builds on every push/PR
- **Publish**: Auto-publishes to NPM on version tags (`v*`)

**Usage**:
```bash
# Trigger publishing
git tag v1.0.1
git push origin v1.0.1
```

## CI/CD Integration

**GitHub Actions**:
```yaml
- run: ./build.sh --ci
```

**Other CI systems**:
```bash
./build.sh --ci
```
