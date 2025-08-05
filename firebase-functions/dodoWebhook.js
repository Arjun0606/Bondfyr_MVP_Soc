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
                console.log('👥 Processing guest payment');
                await processGuestPayment(afterpartyId, userId, paymentId, metadata);
                console.log('✅ Guest payment processed successfully');
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

// Process guest payment and add to activeUsers
async function processGuestPayment(afterpartyId, userId, paymentId, metadata) {
    try {
        console.log('🔍 Processing guest payment for party:', afterpartyId);
    
        // Get the afterparty
        const afterpartyRef = db.collection('afterparties').doc(afterpartyId);
        const afterpartyDoc = await afterpartyRef.get();
        
        if (!afterpartyDoc.exists) {
            console.error('❌ Afterparty not found:', afterpartyId);
            throw new Error('Afterparty not found');
        }
        
        const afterpartyData = afterpartyDoc.data();
        console.log('✅ Found afterparty data');
        
        // Update guest request payment status and add to activeUsers
        const guestRequests = afterpartyData.guestRequests || [];
        const activeUsers = afterpartyData.activeUsers || [];
        
        // Find and update the guest request
        const updatedRequests = guestRequests.map(request => {
            if (request.userId === userId) {
                return {
                    ...request,
                    paymentStatus: 'paid',
                    dodoPaymentId: paymentId,
                    paidAt: admin.firestore.FieldValue.serverTimestamp()
                };
            }
            return request;
        });
        
        // Add user to activeUsers if not already there
        const updatedActiveUsers = [...activeUsers];
        if (!updatedActiveUsers.includes(userId)) {
            updatedActiveUsers.push(userId);
            console.log('✅ Added user to activeUsers:', userId);
        }
        
        // Update the afterparty document
        await afterpartyRef.update({
            guestRequests: updatedRequests,
            activeUsers: updatedActiveUsers
        });
        
        console.log('✅ Guest payment processed and user added to activeUsers');
        
        // Send confirmation notification to guest
        await sendGuestPaymentConfirmation(userId, afterpartyData.title);
        console.log('✅ Payment confirmation sent');
        
    } catch (error) {
        console.error('❌ Error processing guest payment:', error);
        throw error;
    }
} 

async function sendHostListingFeeConfirmation(userId, amount) {
    console.log(`🎉 DODO: Sending listing fee confirmation to host ${userId}`);
    
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.log('❌ DODO: User not found for listing fee confirmation');
            return;
        }
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
            console.log('❌ DODO: No FCM token for listing fee confirmation');
            return;
        }
        
        const message = {
            token: fcmToken,
            notification: {
                title: '✅ Listing Fee Paid',
                body: `Your $${amount} listing fee has been processed. Your party is now live on Bondfyr!`
            },
            data: {
                type: 'listing_fee_confirmed',
                amount: amount.toString(),
                sentAt: new Date().toISOString()
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1
                    }
                }
            }
        };
        
        const response = await admin.messaging().send(message);
        console.log('✅ DODO: Listing fee confirmation sent:', response);
        
    } catch (error) {
        console.error('❌ DODO: Error sending listing fee confirmation:', error);
    }
}

async function sendGuestPaymentConfirmation(userId, partyTitle) {
    console.log(`🎉 DODO: Sending guest payment confirmation to ${userId}`);
    
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.log('❌ DODO: User not found for guest payment confirmation');
            return;
        }
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
            console.log('❌ DODO: No FCM token for guest payment confirmation');
            return;
        }
        
        const message = {
            token: fcmToken,
            notification: {
                title: '🎉 Payment Confirmed!',
                body: `Your payment for ${partyTitle} has been confirmed. You're officially going!`
            },
            data: {
                type: 'guest_payment_confirmed',
                partyTitle: partyTitle,
                sentAt: new Date().toISOString()
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1
                    }
                }
            }
        };
        
        const response = await admin.messaging().send(message);
        console.log('✅ DODO: Guest payment confirmation sent:', response);
        
    } catch (error) {
        console.error('❌ DODO: Error sending guest payment confirmation:', error);
    }
} 