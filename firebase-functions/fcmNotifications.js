const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * Send FCM push notification to a specific user
 * This function solves the critical issue where notifications were only showing 
 * on the device that triggered them, not the target recipient's device.
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
    console.log('🚀 FCM Function: sendPushNotification called');
    console.log('🚀 FCM Function: Data received:', JSON.stringify(data, null, 2));
    
    try {
        const { targetUserId, title, body, data: notificationData = {}, platform = 'ios' } = data;
        
        // Validate required fields
        if (!targetUserId || !title || !body) {
            throw new functions.https.HttpsError(
                'invalid-argument', 
                'Missing required fields: targetUserId, title, body'
            );
        }
        
        // Get user's FCM token from Firestore
        console.log('🔍 FCM Function: Getting FCM token for user:', targetUserId);
        const userDoc = await db.collection('users').doc(targetUserId).get();
        
        if (!userDoc.exists) {
            throw new functions.https.HttpsError(
                'not-found', 
                `User ${targetUserId} not found`
            );
        }
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
            console.log('🔴 FCM Function: No FCM token found for user:', targetUserId);
            throw new functions.https.HttpsError(
                'failed-precondition', 
                `No FCM token found for user ${targetUserId}`
            );
        }
        
        console.log('🟢 FCM Function: Found FCM token for user:', targetUserId);
        
        // Prepare FCM message
        const message = {
            token: fcmToken,
            notification: {
                title: title,
                body: body,
            },
            data: {
                ...notificationData,
                targetUserId: targetUserId,
                platform: platform,
                sentAt: new Date().toISOString()
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        'content-available': 1
                    }
                }
            }
        };
        
        console.log('📤 FCM Function: Sending message:', JSON.stringify(message, null, 2));
        
        // Send the notification
        const response = await admin.messaging().send(message);
        console.log('✅ FCM Function: Notification sent successfully:', response);
        
        // Log to Firestore for analytics
        await db.collection('notificationLogs').add({
            targetUserId: targetUserId,
            title: title,
            body: body,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            fcmResponse: response,
            platform: platform,
            status: 'sent'
        });
        
        return { 
            success: true, 
            messageId: response,
            message: 'Notification sent successfully' 
        };
        
    } catch (error) {
        console.error('🔴 FCM Function: Error sending notification:', error);
        
        // Log error to Firestore
        try {
            await db.collection('notificationLogs').add({
                targetUserId: data.targetUserId || 'unknown',
                title: data.title || 'unknown',
                error: error.message,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'error'
            });
        } catch (logError) {
            console.error('🔴 FCM Function: Error logging notification error:', logError);
        }
        
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        
        throw new functions.https.HttpsError(
            'internal', 
            `Failed to send notification: ${error.message}`
        );
    }
});

/**
 * HTTP endpoint version for direct REST calls from iOS app
 */
exports.sendPushNotificationHTTP = functions.https.onRequest(async (req, res) => {
    console.log('🌐 FCM HTTP: sendPushNotificationHTTP called');
    
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    
    if (req.method !== 'POST') {
        res.status(405).send('Method Not Allowed');
        return;
    }
    
    try {
        const { targetUserId, title, body, data: notificationData = {}, platform = 'ios' } = req.body;
        
        console.log('🌐 FCM HTTP: Request body:', JSON.stringify(req.body, null, 2));
        
        // Validate required fields
        if (!targetUserId || !title || !body) {
            res.status(400).json({
                error: 'Missing required fields: targetUserId, title, body'
            });
            return;
        }
        
        // Get user's FCM token from Firestore
        console.log('🔍 FCM HTTP: Getting FCM token for user:', targetUserId);
        const userDoc = await db.collection('users').doc(targetUserId).get();
        
        if (!userDoc.exists) {
            res.status(404).json({
                error: `User ${targetUserId} not found`
            });
            return;
        }
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
            console.log('🔴 FCM HTTP: No FCM token found for user:', targetUserId);
            res.status(422).json({
                error: `No FCM token found for user ${targetUserId}`
            });
            return;
        }
        
        console.log('🟢 FCM HTTP: Found FCM token for user:', targetUserId);
        
        // Prepare FCM message
        const message = {
            token: fcmToken,
            notification: {
                title: title,
                body: body,
            },
            data: {
                ...notificationData,
                targetUserId: targetUserId,
                platform: platform,
                sentAt: new Date().toISOString()
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        'content-available': 1
                    }
                }
            }
        };
        
        console.log('📤 FCM HTTP: Sending message:', JSON.stringify(message, null, 2));
        
        // Send the notification
        const response = await admin.messaging().send(message);
        console.log('✅ FCM HTTP: Notification sent successfully:', response);
        
        // Log to Firestore for analytics
        await db.collection('notificationLogs').add({
            targetUserId: targetUserId,
            title: title,
            body: body,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            fcmResponse: response,
            platform: platform,
            status: 'sent'
        });
        
        res.status(200).json({ 
            success: true, 
            messageId: response,
            message: 'Notification sent successfully' 
        });
        
    } catch (error) {
        console.error('🔴 FCM HTTP: Error sending notification:', error);
        
        // Log error to Firestore
        try {
            await db.collection('notificationLogs').add({
                targetUserId: req.body.targetUserId || 'unknown',
                title: req.body.title || 'unknown',
                error: error.message,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'error'
            });
        } catch (logError) {
            console.error('🔴 FCM HTTP: Error logging notification error:', logError);
        }
        
        res.status(500).json({
            error: 'Failed to send notification',
            details: error.message
        });
    }
});

/**
 * Test function to verify FCM setup
 */
exports.testFCMNotification = functions.https.onCall(async (data, context) => {
    console.log('🧪 FCM Test: Testing FCM notification system');
    
    const { targetUserId } = data;
    
    if (!targetUserId) {
        throw new functions.https.HttpsError(
            'invalid-argument', 
            'Missing targetUserId for test'
        );
    }
    
    // Send test notification
    try {
        const result = await exports.sendPushNotification.handler({
            targetUserId: targetUserId,
            title: '🧪 Test Notification',
            body: 'FCM push notifications are working correctly!',
            data: {
                type: 'test',
                timestamp: new Date().toISOString()
            }
        }, context);
        
        console.log('🟢 FCM Test: Test notification sent successfully');
        return { success: true, result: result };
        
    } catch (error) {
        console.error('🔴 FCM Test: Test notification failed:', error);
        throw new functions.https.HttpsError(
            'internal', 
            `Test notification failed: ${error.message}`
        );
    }
}); 