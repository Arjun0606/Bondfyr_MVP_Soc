const functions = require('firebase-functions');
const admin = require('firebase-admin');

// If admin is not already initialized elsewhere
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Cleans up old chat messages
 * Retention period: 30 days for city chats, 7 days for event chats
 */
exports.cleanupOldChatMessages = functions.https.onRequest(async (req, res) => {
  try {
    // Timestamp for 30 days ago for city chats
    const cityRetentionLimit = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    );
    
    // Timestamp for 7 days ago for event chats
    const eventRetentionLimit = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );
    
    // Get old city chat messages
    const oldCityMessages = await db.collection('chat_messages')
      .where('eventId', '==', null)
      .where('timestamp', '<', cityRetentionLimit)
      .where('isSystemMessage', '==', false)
      .limit(500)  // Process in batches
      .get();
    
    // Get old event chat messages
    const oldEventMessages = await db.collection('chat_messages')
      .where('eventId', '!=', null)
      .where('timestamp', '<', eventRetentionLimit)
      .where('isSystemMessage', '==', false)
      .limit(500)  // Process in batches
      .get();
    
    // Batch delete
    const batch = db.batch();
    
    oldCityMessages.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    oldEventMessages.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Commit the batch
    if (oldCityMessages.size > 0 || oldEventMessages.size > 0) {
      await batch.commit();
      functions.logger.info(`Cleaned up ${oldCityMessages.size} city messages and ${oldEventMessages.size} event messages`);
      res.json({ success: true, cityMessagesDeleted: oldCityMessages.size, eventMessagesDeleted: oldEventMessages.size });
    } else {
      functions.logger.info('No old messages to clean up');
      res.json({ success: true, message: 'No old messages to clean up' });
    }
    
    return null;
  } catch (error) {
    functions.logger.error('Error cleaning up old chat messages:', error);
    res.status(500).json({ error: error.message });
    return null;
  }
});

/**
 * Reset member counts for all chats at midnight
 * This helps keep the counts accurate
 */
exports.resetChatMemberCounts = functions.pubsub.schedule('every day 00:00').onRun(async (context) => {
  try {
    // Reset city chat member counts
    const citiesSnapshot = await db.collection('chat_cities').get();
    
    // Reset event chat member counts
    const eventChatsSnapshot = await db.collection('event_chats').get();
    
    const batch = db.batch();
    
    // Reset city counts
    citiesSnapshot.forEach(doc => {
      batch.update(doc.ref, { memberCount: 0 });
    });
    
    // Reset event counts
    eventChatsSnapshot.forEach(doc => {
      batch.update(doc.ref, { memberCount: 0 });
    });
    
    // Commit the batch
    await batch.commit();
    
    functions.logger.info(`Reset member counts for ${citiesSnapshot.size} cities and ${eventChatsSnapshot.size} events`);
    return null;
  } catch (error) {
    functions.logger.error('Error resetting chat member counts:', error);
    return null;
  }
});

/**
 * When a message is created, update the lastActiveTimestamp for the corresponding chat
 */
exports.updateChatActivity = functions.firestore.document('chat_messages/{messageId}').onCreate(async (snapshot, context) => {
  try {
    const message = snapshot.data();
    const timestamp = admin.firestore.Timestamp.now();
    
    if (message.eventId) {
      // Update event chat activity
      await db.collection('event_chats').doc(message.eventId).update({
        lastActiveTimestamp: timestamp
      });
    } else if (message.cityId) {
      // Update city chat activity
      await db.collection('chat_cities').doc(message.cityId).update({
        lastActiveTimestamp: timestamp
      });
    }
    
    return null;
  } catch (error) {
    functions.logger.error('Error updating chat activity:', error);
    return null;
  }
});

/**
 * When a user is deleted, remove their chat messages
 */
exports.cleanupUserChatMessages = functions.auth.user().onDelete(async (user) => {
  try {
    const userId = user.uid;
    
    // Get all messages by the deleted user
    const messagesSnapshot = await db.collection('chat_messages')
      .where('userId', '==', userId)
      .limit(500) // Process in batches
      .get();
    
    if (messagesSnapshot.empty) {
      functions.logger.info(`No chat messages found for deleted user ${userId}`);
      return null;
    }
    
    // Delete all messages in a batch
    const batch = db.batch();
    
    messagesSnapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    
    functions.logger.info(`Deleted ${messagesSnapshot.size} chat messages for user ${userId}`);
    return null;
  } catch (error) {
    functions.logger.error('Error cleaning up user chat messages:', error);
    return null;
  }
});

/**
 * Creates a test event chat with 10-minute expiration
 * This is used for testing the event chat functionality
 */
exports.createTestEventChat = functions.https.onRequest(async (req, res) => {
  try {
    const eventId = req.query.eventId || "test-event";
    const eventName = req.query.eventName || "Test Event";
    
    // Check if event chat exists
    const eventChatDoc = await db.collection('event_chats').doc(eventId).get();
    
    // Create or update the event chat
    await db.collection('event_chats').doc(eventId).set({
      id: eventId,
      eventId: eventId,
      name: eventName,
      memberCount: 0,
      lastActiveTimestamp: admin.firestore.Timestamp.now(),
      // Set expiration to 10 minutes from now for testing
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 10 * 60 * 1000)
      )
    });
    
    // Delete all existing messages for this event
    const existingMessages = await db.collection('chat_messages')
      .where('eventId', '==', eventId)
      .get();
    
    if (!existingMessages.empty) {
      const batch = db.batch();
      existingMessages.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      functions.logger.info(`Cleared ${existingMessages.size} previous messages from event chat ${eventId}`);
    }
    
    // Add welcome system message
    await db.collection('chat_messages').add({
      id: admin.firestore.Timestamp.now().toMillis().toString(),
      cityId: '',
      userId: 'system',
      displayName: 'System',
      text: `Welcome to the ${eventName} chat! This chat will expire in 10 minutes.`,
      timestamp: admin.firestore.Timestamp.now(),
      isSystemMessage: true,
      eventId: eventId
    });
    
    res.json({
      success: true,
      message: `Test event chat created/reset for ${eventName} with ID ${eventId}. Expires in 10 minutes.`,
      eventChat: {
        id: eventId,
        name: eventName,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000)
      }
    });
    return null;
  } catch (error) {
    functions.logger.error('Error creating test event chat:', error);
    res.status(500).json({ error: error.message });
    return null;
  }
});

/**
 * Check for expired event chats and mark them as inactive
 */
exports.checkExpiredEventChats = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  try {
    const now = admin.firestore.Timestamp.now();
    
    // Get event chats that have expired
    const expiredChatsSnapshot = await db.collection('event_chats')
      .where('expiresAt', '<', now)
      .get();
    
    if (expiredChatsSnapshot.empty) {
      functions.logger.info('No expired event chats found');
      return null;
    }
    
    functions.logger.info(`Found ${expiredChatsSnapshot.size} expired event chats`);
    
    // Update each expired chat
    const batch = db.batch();
    expiredChatsSnapshot.forEach(doc => {
      batch.update(doc.ref, { 
        isExpired: true,
        memberCount: 0
      });
    });
    
    await batch.commit();
    
    functions.logger.info(`Marked ${expiredChatsSnapshot.size} event chats as expired`);
    return null;
  } catch (error) {
    functions.logger.error('Error checking expired event chats:', error);
    return null;
  }
}); 