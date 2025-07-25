const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

// LemonSqueezy Webhook Handler
exports.lemonSqueezyWebhook = functions.https.onRequest(async (req, res) => {
    console.log('🍋 LemonSqueezy Webhook received');
    console.log('🍋 Method:', req.method);
    console.log('🍋 Headers:', req.headers);
    console.log('🍋 Body:', req.body);

    if (req.method !== 'POST') {
        console.log('❌ Invalid method:', req.method);
        return res.status(405).send('Method Not Allowed');
    }

    try {
        // Verify webhook signature (optional but recommended)
        const signature = req.headers['x-signature'];
        const body = JSON.stringify(req.body);
        
        // For now, we'll skip signature verification since it's test mode
        // In production, you should verify the signature
        
        const eventType = req.body.meta?.event_name;
        console.log('🍋 Event type:', eventType);

        // Handle order_created event (payment completed)
        if (eventType === 'order_created') {
            await handleOrderCreated(req.body);
        }

        res.status(200).send('Webhook received');

    } catch (error) {
        console.error('🔴 Webhook error:', error);
        res.status(500).send('Webhook processing failed');
    }
});

async function handleOrderCreated(webhookData) {
    console.log('🍋 Processing order_created webhook');
    
    try {
        const orderData = webhookData.data;
        const attributes = orderData.attributes;
        
        // Debug: Log the entire webhook payload to find custom data
        console.log('🔍 FULL WEBHOOK BODY:', JSON.stringify(webhookData, null, 2));
        
        // Get order/checkout ID to look up mapping
        const orderId = orderData.id;
        console.log('🔍 ORDER ID:', orderId);
        
        // CRITICAL FIX: Use custom data from checkout_data first (most reliable)
        const checkoutData = attributes.checkout_data || {};
        const custom = checkoutData.custom || {};
        
        let afterpartyId = custom.afterpartyId;
        let userId = custom.userId;
        
        console.log('🔍 CUSTOM DATA FROM WEBHOOK:', JSON.stringify(custom, null, 2));
        
        // If custom data exists, use it directly (most reliable)
        if (afterpartyId && userId) {
            console.log('✅ FOUND PARTY DATA IN CUSTOM FIELDS');
        } else {
            console.log('⚠️ No custom data, trying checkout mapping lookup...');
            
            // Fallback: Look up checkout mapping in Firebase
            const db = admin.firestore();
            const mappingDoc = await db.collection('checkoutMappings').doc(orderId).get();
            
            if (mappingDoc.exists) {
                const mappingData = mappingDoc.data();
                console.log('✅ FOUND CHECKOUT MAPPING:', JSON.stringify(mappingData, null, 2));
                
                afterpartyId = mappingData.afterpartyId;
                userId = mappingData.userId;
            } else {
                console.log('❌ NO CHECKOUT MAPPING FOUND FOR:', orderId);
            }
        }
        
        const checkoutId = orderId;
        
        console.log('🍋 Order details:');
        console.log('  - Order ID:', orderData.id);
        console.log('  - Afterparty ID:', afterpartyId);
        console.log('  - User ID:', userId);
        console.log('  - Total:', attributes.total);
        console.log('  - Status:', attributes.status);

        if (!afterpartyId || !userId) {
            console.error('❌ Missing required data in webhook:', {afterpartyId, userId});
            return;
        }

        // Only process if payment is successful
        if (attributes.status === 'paid') {
            await createPartyFromPending(afterpartyId, userId, checkoutId);
            await sendPaymentConfirmationNotification(userId, afterpartyId);
        } else {
            console.log('⏳ Order not yet paid, status:', attributes.status);
        }

    } catch (error) {
        console.error('🔴 Error processing order:', error);
        throw error;
    }
}

async function createPartyFromPending(afterpartyId, userId, checkoutId) {
    console.log('🍋 Creating party from pending data');
    console.log('  - Afterparty ID:', afterpartyId);
    console.log('  - User ID:', userId);
    console.log('  - Checkout ID:', checkoutId);

    const db = admin.firestore();

    try {
        // Get pending party data
        const pendingDoc = await db.collection('pendingParties').doc(afterpartyId).get();
        
        if (!pendingDoc.exists) {
            console.error('❌ Pending party not found:', afterpartyId);
            throw new Error('Pending party not found');
        }

        const pendingData = pendingDoc.data();
        console.log('📋 Found pending party data:', Object.keys(pendingData));

        // Create the actual party
        const partyData = {
            ...pendingData,
            listingFeePaid: true,
            paidAt: admin.firestore.Timestamp.now(),
            createdAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.Timestamp.now(),
            status: 'active',
            lemonSqueezyCheckoutId: checkoutId,
            lemonSqueezyOrderId: checkoutId // Store order ID for reference
        };

        // Add host to activeUsers
        if (pendingData.hostId) {
            partyData.activeUsers = [pendingData.hostId];
        }

        // Create party document
        await db.collection('afterparties').doc(afterpartyId).set(partyData);
        console.log('✅ Created party:', afterpartyId);

        // Delete pending party data
        await db.collection('pendingParties').doc(afterpartyId).delete();
        console.log('🗑️ Deleted pending party data');
        
        // Clean up checkout mapping
        await db.collection('checkoutMappings').doc(checkoutId).delete();
        console.log('🗑️ Deleted checkout mapping');

        // Send success notification to host
        await sendPartyCreatedNotification(pendingData.hostId, pendingData.title);

    } catch (error) {
        console.error('🔴 Error creating party:', error);
        throw error;
    }
}

async function sendPartyCreatedNotification(hostId, partyTitle) {
    console.log('🔔 Sending party created notification to:', hostId);
    
    try {
        const db = admin.firestore();
        
        // Get host's FCM token
        const userDoc = await db.collection('users').doc(hostId).get();
        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;

        if (!fcmToken) {
            console.log('⚠️ No FCM token found for host:', hostId);
            return;
        }

        const message = {
            token: fcmToken,
            notification: {
                title: '🎉 Party Created!',
                body: `Your party "${partyTitle}" is now live and accepting guests!`
            },
            data: {
                type: 'party_created',
                partyTitle: partyTitle || 'Your Party'
            }
        };

        const response = await admin.messaging().send(message);
        console.log('✅ Party created notification sent:', response);

    } catch (error) {
        console.error('🔴 Error sending party created notification:', error);
    }
}

async function sendPaymentConfirmationNotification(userId, afterpartyId) {
    console.log('🔔 Sending payment confirmation to:', userId);
    
    try {
        const db = admin.firestore();
        
        // Get user's FCM token
        const userDoc = await db.collection('users').doc(userId).get();
        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;

        if (!fcmToken) {
            console.log('⚠️ No FCM token found for user:', userId);
            return;
        }

        const message = {
            token: fcmToken,
            notification: {
                title: '✅ Payment Confirmed!',
                body: 'Your listing fee payment was processed successfully. Your party is being created!'
            },
            data: {
                type: 'payment_confirmed',
                afterpartyId: afterpartyId
            }
        };

        const response = await admin.messaging().send(message);
        console.log('✅ Payment confirmation sent:', response);

    } catch (error) {
        console.error('🔴 Error sending payment confirmation:', error);
    }
} 