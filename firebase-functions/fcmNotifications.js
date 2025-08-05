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

/**
 * Generate notification analytics report for production monitoring
 */
exports.generateNotificationAnalytics = functions.https.onCall(async (data, context) => {
    console.log('📊 Analytics: generateNotificationAnalytics called');
    
    try {
        const { timeRange = '7d' } = data;
        
        // Calculate date range
        const now = new Date();
        let startDate;
        
        switch(timeRange) {
            case '1d':
                startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
                break;
            case '7d':
                startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                break;
            case '30d':
                startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
                break;
            default:
                startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        }
        
        // Get notification analytics
        const analyticsQuery = await db.collection('notificationAnalytics')
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startDate))
            .get();
        
        // Get engagement data
        const engagementQuery = await db.collection('notificationEngagement')
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startDate))
            .get();
        
        // Process analytics data
        const analytics = {
            totalAttempts: 0,
            totalDelivered: 0,
            totalFailed: 0,
            totalOpened: 0,
            deliveryRate: 0,
            openRate: 0,
            typeBreakdown: {},
            dailyStats: {},
            errors: {}
        };
        
        // Process notification attempts/delivery
        analyticsQuery.forEach(doc => {
            const data = doc.data();
            const type = data.type || 'unknown';
            const status = data.status || 'unknown';
            const date = data.timestamp?.toDate()?.toISOString()?.split('T')[0] || 'unknown';
            
            // Initialize type breakdown
            if (!analytics.typeBreakdown[type]) {
                analytics.typeBreakdown[type] = { attempted: 0, delivered: 0, failed: 0, opened: 0 };
            }
            
            // Initialize daily stats
            if (!analytics.dailyStats[date]) {
                analytics.dailyStats[date] = { attempted: 0, delivered: 0, failed: 0, opened: 0 };
            }
            
            // Count totals
            if (status === 'attempted') {
                analytics.totalAttempts++;
                analytics.typeBreakdown[type].attempted++;
                analytics.dailyStats[date].attempted++;
            } else if (status === 'delivered') {
                analytics.totalDelivered++;
                analytics.typeBreakdown[type].delivered++;
                analytics.dailyStats[date].delivered++;
            } else if (status === 'failed') {
                analytics.totalFailed++;
                analytics.typeBreakdown[type].failed++;
                analytics.dailyStats[date].failed++;
                
                // Track error types
                const error = data.error || 'unknown';
                analytics.errors[error] = (analytics.errors[error] || 0) + 1;
            }
        });
        
        // Process engagement data
        engagementQuery.forEach(doc => {
            const data = doc.data();
            const type = data.type || 'unknown';
            const date = data.timestamp?.toDate()?.toISOString()?.split('T')[0] || 'unknown';
            
            analytics.totalOpened++;
            
            if (analytics.typeBreakdown[type]) {
                analytics.typeBreakdown[type].opened++;
            }
            
            if (analytics.dailyStats[date]) {
                analytics.dailyStats[date].opened++;
            }
        });
        
        // Calculate rates
        analytics.deliveryRate = analytics.totalAttempts > 0 
            ? Math.round((analytics.totalDelivered / analytics.totalAttempts) * 100) 
            : 0;
        analytics.openRate = analytics.totalDelivered > 0 
            ? Math.round((analytics.totalOpened / analytics.totalDelivered) * 100) 
            : 0;
        
        console.log('📊 Analytics: Report generated successfully');
        console.log(`📊 Analytics: ${analytics.totalAttempts} attempts, ${analytics.totalDelivered} delivered, ${analytics.totalOpened} opened`);
        
        return {
            success: true,
            timeRange,
            analytics,
            generatedAt: new Date().toISOString()
        };
        
    } catch (error) {
        console.error('❌ Analytics: Error generating report:', error);
        throw new functions.https.HttpsError('internal', 'Failed to generate analytics report');
    }
}); 