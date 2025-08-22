#!/bin/bash
# Nexus3 Deploy Unified Application Startup Script

echo "Starting Nexus3 Deploy Application..."
echo "Installing dependencies..."
cd backend && npm install

echo "Starting server..."
npm start