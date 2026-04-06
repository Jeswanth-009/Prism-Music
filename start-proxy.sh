#!/bin/bash

echo "Starting Prism Music Proxy Server..."
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH."
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Change to proxy server directory
cd "$(dirname "$0")/proxy-server"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install dependencies."
        exit 1
    fi
    echo
fi

# Start the server
echo "Starting proxy server on port 3000..."
echo "Press Ctrl+C to stop the server"
echo
npm start