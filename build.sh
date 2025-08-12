#!/bin/bash
set -e

# Simple build script for React Native Appstack SDK
# Usage: ./build.sh [--clean] [--ci]

CLEAN_BUILD=false
CI_MODE=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --clean) CLEAN_BUILD=true ;;
    --ci) CI_MODE=true ;;
    --help|-h) 
      echo "Usage: $0 [--clean] [--ci]"
      echo "  --clean  Clean previous builds"
      echo "  --ci     CI mode (use npm ci, run tests)"
      exit 0 ;;
  esac
done

echo "🚀 Building React Native Appstack SDK..."

# Clean if requested
if [[ "$CLEAN_BUILD" == true ]]; then
  echo "🧹 Cleaning previous builds..."
  rm -rf lib node_modules
fi

# Install dependencies
if [[ "$CI_MODE" == true ]]; then
  echo "📦 Installing dependencies (CI mode)..."
  npm ci
  echo "🔍 Running tests..."
  npm run lint
  npm run typecheck
  npm test
else
  echo "📦 Installing dependencies..."
  npm install
fi

# Build
echo "🏗️ Building..."
npm run prepack

# Verify
echo "✅ Verifying build..."
for file in "lib/commonjs/index.js" "lib/module/index.js" "lib/typescript/index.d.ts"; do
  [[ ! -f "$file" ]] && echo "❌ Missing: $file" && exit 1
done

echo "✅ Build completed successfully!"
