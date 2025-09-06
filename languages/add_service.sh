#!/bin/bash

# Universal Language Service Generator
# Adds CGI services for any supported language using the modular language system
# Usage: ./add_language_service.sh <language> <app_name> <start_port> [instance_count]

set -e

LANGUAGE="$1"
APP_NAME="$2"
START_PORT="$3"
INSTANCE_COUNT="${4:-2}"

if [ -z "$LANGUAGE" ] || [ -z "$APP_NAME" ] || [ -z "$START_PORT" ]; then
    echo "Usage: $0 <language> <app_name> <start_port> [instance_count]"
    echo ""
    echo "Available languages:"
    ./languages/manager.py list | grep "  " | sed 's/^  /    /'
    echo ""
    echo "Examples:"
    echo "  $0 python analytics 8007 3"
    echo "  $0 csharp orders 8009 2"
    echo "  $0 javascript api 8011 4"
    exit 1
fi

echo "🚀 Universal Language Service Generator"
echo "======================================="
echo "Language: $LANGUAGE"
echo "Service: $APP_NAME"  
echo "Port: $START_PORT"
echo "Instances: $INSTANCE_COUNT"
echo ""

# Check if language is supported
if ! ./languages/manager.py info --language "$LANGUAGE" >/dev/null 2>&1; then
    echo "❌ Error: Language '$LANGUAGE' not supported"
    echo ""
    echo "Available languages:"
    ./languages/manager.py list
    exit 1
fi

# Get language info
LANG_INFO=$(./languages/manager.py info --language "$LANGUAGE")
echo "📋 Language Info:"
echo "$LANG_INFO" | sed 's/^/   /'
echo ""

# Generate automation script for this language
TEMP_SCRIPT="/tmp/add_${LANGUAGE}_service_$$.sh"
echo "🔧 Generating automation script for $LANGUAGE..."

./languages/manager.py generate-script --language "$LANGUAGE" --output "$TEMP_SCRIPT"

if [ ! -f "$TEMP_SCRIPT" ]; then
    echo "❌ Failed to generate automation script"
    exit 1
fi

echo "✅ Generated temporary automation script"

# Execute the generated script
echo "🏃 Executing service creation..."
echo ""

"$TEMP_SCRIPT" "$APP_NAME" "$START_PORT" "$INSTANCE_COUNT"

# Clean up
rm -f "$TEMP_SCRIPT"

echo ""
echo "🎉 Successfully added $APP_NAME ($LANGUAGE) service!"
echo ""
echo "🔍 Next steps:"
echo "   1. Review generated files for correctness"
echo "   2. Test the service: make run-pool && make run-yarp"
echo "   3. Monitor at: http://localhost:8080/admin"
echo ""