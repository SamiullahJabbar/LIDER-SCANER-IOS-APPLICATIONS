#!/bin/bash

# Flutter App Setup Script
# Production-ready installation

set -e

echo "🚀 Setting up Flutter app..."
echo ""

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed!"
    echo "Please install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Generate model code
echo "🔨 Generating JSON serialization code..."
flutter pub run build_runner build --delete-conflicting-outputs

# Check for errors
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "📱 Next steps:"
    echo "1. Connect your device or start emulator"
    echo "2. Run: flutter run"
    echo ""
    echo "🔧 Backend setup:"
    echo "1. Make sure backend is running on http://localhost:8000"
    echo "2. Or configure backend URL in app settings"
    echo ""
else
    echo ""
    echo "❌ Setup failed!"
    echo "Please check the errors above"
    exit 1
fi
