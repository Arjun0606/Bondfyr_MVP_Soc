#!/bin/bash

# Bondfyr Firebase Chat Setup Script
# This script helps set up the Firebase chat functionality

echo "========================================"
echo "   Bondfyr Firebase Chat Setup Script   "
echo "========================================"
echo ""

# Check if firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in to Firebase
firebase projects:list &> /dev/null
if [ $? -ne 0 ]; then
    echo "You need to log in to Firebase first. Run:"
    echo "firebase login"
    exit 1
fi

# Prompt for Firebase project ID
echo "Enter your Firebase project ID:"
read PROJECT_ID

# Set the project
echo "Setting Firebase project to $PROJECT_ID..."
firebase use $PROJECT_ID

if [ $? -ne 0 ]; then
    echo "Failed to set Firebase project. Make sure the project ID is correct."
    exit 1
fi

# Check if serviceAccountKey.json exists
if [ ! -f "serviceAccountKey.json" ]; then
    echo "serviceAccountKey.json not found in the current directory."
    echo "Please download it from your Firebase project settings (Service accounts tab)"
    echo "and place it in this directory before continuing."
    exit 1
fi

# Deploy Firestore rules
echo "Deploying Firestore security rules..."
firebase deploy --only firestore:rules

if [ $? -ne 0 ]; then
    echo "Failed to deploy Firestore rules."
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
npm install firebase-admin

# Initialize chat data
echo "Initializing chat data (cities and event chats)..."
node init-chat-data.js

if [ $? -ne 0 ]; then
    echo "Failed to initialize chat data."
    exit 1
fi

# Deploy Firebase functions
echo "Deploying Firebase functions for chat management..."
cd ../firebase-functions
npm install
firebase deploy --only functions

if [ $? -ne 0 ]; then
    echo "Failed to deploy Firebase functions."
    exit 1
fi

echo ""
echo "========================================"
echo "    Chat Setup Completed Successfully   "
echo "========================================"
echo ""
echo "Your Firebase project now has:"
echo "- Firestore security rules for chat"
echo "- Initialized city chats"
echo "- Event chat setup for existing events"
echo "- Cloud Functions for chat maintenance"
echo ""
echo "Additional steps:"
echo "1. Make sure your app's GoogleService-Info.plist is up to date"
echo "2. Verify the chat functionality in your app"
echo ""

exit 0 