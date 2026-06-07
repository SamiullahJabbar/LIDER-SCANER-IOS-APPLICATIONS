#!/bin/bash

# Generate JSON serialization code for models
echo "🔨 Generating model serialization code..."

flutter pub run build_runner build --delete-conflicting-outputs

echo "✅ Model generation complete!"
