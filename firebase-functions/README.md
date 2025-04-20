# Bondfyr Firebase Functions

This directory contains Firebase Cloud Functions for the Bondfyr app.

## Setup and Deployment

1. Install Firebase CLI if you haven't already:
   ```
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```
   firebase login
   ```

3. Initialize your project (if not already done):
   ```
   firebase init functions
   ```

4. Deploy the functions:
   ```
   firebase deploy --only functions
   ```

## Functions

### onUserDeleted
Triggered when a user is deleted from Firebase Authentication. This function:
- Deletes the user's document from the `users` collection
- Deletes the user's tickets from the `tickets` collection
- Marks the user's photos for deletion in the `photo_contests` collection

This ensures that when a user deletes their account from the app, all their data is properly cleaned up in Firestore. 