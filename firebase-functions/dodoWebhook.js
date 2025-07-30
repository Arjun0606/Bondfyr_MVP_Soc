const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

// Dodo webhook configuration
const DODO_WEBHOOK_SECRET = 'whsec_Y5nFJYOkWXIggi6afYnFSbcryFHthX1E';

// Dodo webhook handler
exports.dodoWebhook = functions.https.onRequest(async (req, res) => {
    console.log('🔵 DODO WEBHOOK RECEIVED');
    
    try {
    // Only accept POST requests
    if (req.method !== 'POST') {
            console.log('❌ Not POST method');
        res.status(405).send('Method Not Allowed');
        return;
    }
    
        // Get the raw webhook data
        const webhookData = req.body;
        console.log('📦 Raw webhook data received');
        console.log('📦 Event type:', webhookData.type);
        
        // Check if this is a payment.succeeded event
        if (webhookData.type === 'payment.succeeded') {
            console.log('✅ Payment succeeded event detected');
            
            const paymentData = webhookData.data;
            if (!paymentData) {
                console.error('❌ No payment data found');
                res.status(400).send('No payment data');
                return;
            }
            
            const metadata = paymentData.metadata || {};
            console.log('📋 Metadata:', JSON.stringify(metadata, null, 2));
            
            const afterpartyId = metadata.afterpartyId;
            const userId = metadata.userId;
            const hostId = metadata.hostId;
            const paymentId = paymentData.payment_id;
            
            console.log('🔍 Extracted:', { afterpartyId, userId, hostId, paymentId });
            
            if (!afterpartyId || !userId) {
                console.error('❌ Missing required metadata');
                res.status(400).send('Missing metadata');
                return;
            }
            
            // Check if this is a listing fee payment (host creating party)
            const isListingFeePayment = userId === hostId;
            
            if (isListingFeePayment) {
                console.log('🏗️ Processing listing fee payment');
                await createPartyFromPendingData(afterpartyId, userId, paymentId, metadata);
                console.log('✅ Party created successfully');
            } else {
                console.log('👥 This is a guest payment - not implemented yet');
            }
            
            res.status(200).json({ received: true, processed: true });
            
        } else {
            console.log('⚠️ Unhandled event type:', webhookData.type);
            res.status(200).json({ received: true, processed: false });
        }
        
    } catch (error) {
        console.error('❌ Webhook error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Create party from pending data
async function createPartyFromPendingData(afterpartyId, userId, paymentId, metadata) {
    try {
        console.log('🔍 Looking for pending party:', afterpartyId);
    
        // Get pending party data
        const pendingPartyRef = db.collection('pendingParties').doc(afterpartyId);
        const pendingPartyDoc = await pendingPartyRef.get();
        
        if (!pendingPartyDoc.exists) {
            console.error('❌ Pending party not found:', afterpartyId);
            throw new Error('Pending party not found');
        }
        
        const pendingPartyData = pendingPartyDoc.data();
        console.log('✅ Found pending party data');
        
        // Create the actual party
        const partyRef = db.collection('afterparties').doc(afterpartyId);
        await partyRef.set({
            ...pendingPartyData,
            paymentId: paymentId,
            paymentStatus: 'completed',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            listingFeePaid: true
        });
        
        console.log('✅ Party created in afterparties collection');
        
        // Delete the pending party data
        await pendingPartyRef.delete();
        console.log('✅ Pending party data cleaned up');
        
        // Send notification to host
        await sendPartyCreatedNotification(userId, pendingPartyData.title);
        console.log('✅ Notification sent');
        
    } catch (error) {
        console.error('❌ Error creating party:', error);
        throw error;
    }
}

// Send party created notification
async function sendPartyCreatedNotification(userId, partyTitle) {
    try {
        console.log('📱 Sending party created notification to:', userId);
    
        // Get user's FCM token
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.log('⚠️ User not found for notification');
            return;
        }
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
            console.log('⚠️ No FCM token for user');
            return;
        }
        
        // Send notification
        const message = {
            token: fcmToken,
            notification: {
                title: '🎉 Party Created!',
                body: `Your party "${partyTitle}" is now live and ready for guests!`
            },
            data: {
                type: 'party_created',
                partyTitle: partyTitle
            }
        };
        
        await admin.messaging().send(message);
        console.log('✅ FCM notification sent successfully');
        
    } catch (error) {
        console.error('❌ Error sending notification:', error);
        // Don't throw - notification failure shouldn't break party creation
    }
} 