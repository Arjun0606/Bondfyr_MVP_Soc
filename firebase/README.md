# Bondfyr Chat Firebase Integration

This directory contains the necessary files and instructions to integrate the city chat and event chat functionality with Firebase.

## Setup Instructions

### 1. Firebase Project Configuration

Make sure you have a Firebase project set up. If not, create one at the [Firebase Console](https://console.firebase.google.com/).

### 2. Generate Service Account Key

1. Go to your Firebase project settings
2. Navigate to the "Service accounts" tab
3. Click "Generate new private key"
4. Save the JSON file as `serviceAccountKey.json` in this directory

### 3. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

### 4. Initialize Chat Data

To initialize the chat data (cities and event chats):

```bash
npm install firebase-admin
node init-chat-data.js
```

## Collections Structure

The chat functionality uses the following Firestore collections:

### chat_cities
Stores information about each city chat:
- `id`: Unique identifier (same as the city name)
- `name`: City name (lowercase)
- `displayName`: Display name of the city
- `memberCount`: Number of active users
- `lastActiveTimestamp`: When the chat was last active

### chat_messages
Stores all chat messages (both for cities and events):
- `id`: Unique message ID
- `cityId`: ID of the city (empty for event messages)
- `userId`: User ID of the sender
- `displayName`: Anonymous display name of the sender
- `text`: Message content
- `timestamp`: When the message was sent
- `isSystemMessage`: Whether it's a system message
- `eventId`: ID of the event (null for city messages)

### event_chats
Stores information about event chats:
- `id`: Unique identifier (same as the event ID)
- `eventId`: ID of the event
- `name`: Name of the event
- `memberCount`: Number of active users
- `lastActiveTimestamp`: When the chat was last active

## Important Notes

1. The anonymous display names are generated once per day and stored in UserDefaults
2. Event chats are only accessible after scanning the event QR code (checking in)
3. City chats are available to all authenticated users

## Troubleshooting

If you encounter issues with the chat functionality:

1. Check Firebase console logs for errors
2. Ensure your app has the correct Firebase configuration
3. Verify that security rules are properly deployed
4. Check that the necessary collections exist in Firestore 