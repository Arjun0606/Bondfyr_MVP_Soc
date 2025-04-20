const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Import chat functions
const chatFunctions = require('./chatFunctions');

// Export chat functions
exports.cleanupOldChatMessages = chatFunctions.cleanupOldChatMessages;
exports.resetChatMemberCounts = chatFunctions.resetChatMemberCounts;
exports.updateChatActivity = chatFunctions.updateChatActivity;
exports.cleanupUserChatMessages = chatFunctions.cleanupUserChatMessages;
exports.createTestEventChat = chatFunctions.createTestEventChat;
exports.checkExpiredEventChats = chatFunctions.checkExpiredEventChats;

// Cloud Function triggered when a user is deleted from Authentication
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  console.log(`User ${userId} was deleted from Authentication, cleaning up Firestore data`);
  
  try {
    // Delete user document in the users collection
    await admin.firestore().collection('users').doc(userId).delete();
    console.log(`User document for ${userId} deleted successfully`);
    
    // Delete user tickets
    const ticketsSnapshot = await admin.firestore()
      .collection('tickets')
      .where('userId', '==', userId)
      .get();
    
    const ticketDeletePromises = [];
    ticketsSnapshot.forEach(doc => {
      ticketDeletePromises.push(doc.ref.delete());
    });
    await Promise.all(ticketDeletePromises);
    console.log(`Deleted ${ticketDeletePromises.length} tickets for user ${userId}`);
    
    // Delete user photos
    const photosSnapshot = await admin.firestore()
      .collection('photo_contests')
      .where('userId', '==', userId)
      .get();
    
    const photoDeletePromises = [];
    photosSnapshot.forEach(doc => {
      // Mark as scheduled for deletion instead of hard delete
      photoDeletePromises.push(doc.ref.update({
        scheduledForDeletion: true
      }));
    });
    await Promise.all(photoDeletePromises);
    console.log(`Marked ${photoDeletePromises.length} photos for deletion for user ${userId}`);
    
    // Add more collections to clean up as needed
    
    return { success: true };
  } catch (error) {
    console.error(`Error cleaning up data for user ${userId}:`, error);
    return { error: error.message };
  }
}); 