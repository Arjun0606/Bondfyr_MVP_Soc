#!/bin/bash

echo "🚀 Deploying FCM Notification System to Firebase..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if logged into Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged into Firebase. Please login first:"
    echo "firebase login"
    exit 1
fi

# Navigate to Firebase Functions directory
cd firebase-functions

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Deploy the functions
echo "🚀 Deploying Firebase Functions..."
firebase deploy --only functions:sendPushNotification,functions:sendPushNotificationHTTP,functions:testFCMNotification

if [ $? -eq 0 ]; then
    echo "✅ FCM Notification Functions deployed successfully!"
    echo ""
    echo "🔗 Your functions are now available at:"
    echo "https://us-central1-bondfyr-da123.cloudfunctions.net/sendPushNotificationHTTP"
    echo ""
    echo "🧪 Test your setup by calling the test function from your iOS app"
else
    echo "❌ Deployment failed. Please check the error messages above."
    exit 1
fi 