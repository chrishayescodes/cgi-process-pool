#!/bin/bash

# Compatibility wrapper for the reorganized language system
# Redirects to the new location: languages/add_service.sh

if [ ! -f "languages/add_service.sh" ]; then
    echo "Error: New language system not found at languages/add_service.sh"
    echo "Please ensure the project has been properly reorganized."
    exit 1
fi

echo "🔄 Using reorganized language system..."
exec ./languages/add_service.sh "$@"