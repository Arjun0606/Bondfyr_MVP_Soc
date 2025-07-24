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
    console.log('🔵 Dodo webhook received:', req.method);
    
    // Only accept POST requests
    if (req.method !== 'POST') {
        res.status(405).send('Method Not Allowed');
        return;
    }
    
    try {
        // Get webhook headers
        const webhookId = req.headers['webhook-id'];
        const webhookSignature = req.headers['webhook-signature'];
        const webhookTimestamp = req.headers['webhook-timestamp'];
        
        console.log('📋 Webhook headers:', {
            id: webhookId,
            signature: webhookSignature,
            timestamp: webhookTimestamp
        });
        
        // Verify webhook signature for security
        if (!verifyWebhookSignature(req.body, webhookSignature, DODO_WEBHOOK_SECRET)) {
            console.error('❌ Invalid webhook signature');
            res.status(401).send('Unauthorized');
            return;
        }
        
        console.log('✅ Webhook signature verified');
        
        // Parse the webhook payload
        const event = req.body;
        console.log('📦 Webhook event:', event);
        
        // Handle different event types
        switch (event.event_type) {
            case 'payment.succeeded':
                await handlePaymentSucceeded(event);
                break;
                
            case 'payment.failed':
                await handlePaymentFailed(event);
                break;
                
            case 'refund.succeeded':
                await handleRefundSucceeded(event);
                break;
                
            default:
                console.log(`⚠️ Unhandled event type: ${event.event_type}`);
        }
        
        // Send success response
        res.status(200).json({ received: true });
        
    } catch (error) {
        console.error('❌ Webhook error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Handle successful payment
async function handlePaymentSucceeded(event) {
    console.log('✅ Processing payment.succeeded event');
    
    const payment = event.data;
    const metadata = payment.metadata || {};
    
    // Extract metadata
    const afterpartyId = metadata.afterpartyId;
    const userId = metadata.userId;
    const paymentId = payment.payment_id;
    
    if (!afterpartyId || !userId) {
        console.error('❌ Missing required metadata:', { afterpartyId, userId });
        return;
    }
    
    console.log('💳 Payment details:', {
        afterpartyId,
        userId,
        paymentId,
        amount: payment.amount,
        currency: payment.currency
    });
    
    try {
        // Get the afterparty document
        const afterpartyRef = db.collection('afterparties').doc(afterpartyId);
        const afterpartyDoc = await afterpartyRef.get();
        
        if (!afterpartyDoc.exists) {
            console.error('❌ Afterparty not found:', afterpartyId);
            return;
        }
        
        const afterparty = afterpartyDoc.data();
        
        // Find the guest request
        const guestRequests = afterparty.guestRequests || [];
        const requestIndex = guestRequests.findIndex(req => req.userId === userId);
        
        if (requestIndex === -1) {
            console.error('❌ Guest request not found for user:', userId);
            return;
        }
        
        // Update the guest request with payment info
        guestRequests[requestIndex].paymentStatus = 'paid';
        guestRequests[requestIndex].paymentId = paymentId;
        guestRequests[requestIndex].paidAt = admin.firestore.FieldValue.serverTimestamp();
        
        // Add user to activeUsers if not already there
        const activeUsers = afterparty.activeUsers || [];
        if (!activeUsers.includes(userId)) {
            activeUsers.push(userId);
        }
        
        // Update the afterparty
        await afterpartyRef.update({
            guestRequests: guestRequests,
            activeUsers: activeUsers,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log('✅ Payment processed successfully for user:', userId);
        
        // Send push notification to the user
        await sendPaymentSuccessNotification(userId, afterparty.title);
        
    } catch (error) {
        console.error('❌ Error updating afterparty:', error);
        throw error;
    }
}

// Handle failed payment
async function handlePaymentFailed(event) {
    console.log('❌ Processing payment.failed event');
    
    const payment = event.data;
    const metadata = payment.metadata || {};
    
    // Log the failure for debugging
    console.log('💔 Payment failed:', {
        paymentId: payment.payment_id,
        reason: payment.failure_reason,
        metadata
    });
    
    // You might want to send a notification to the user
    if (metadata.userId) {
        await sendPaymentFailedNotification(metadata.userId);
    }
}

// Handle refund
async function handleRefundSucceeded(event) {
    console.log('💸 Processing refund.succeeded event');
    
    const refund = event.data;
    const paymentId = refund.payment_id;
    
    // Find the afterparty with this payment
    try {
        const afterpartiesSnapshot = await db.collection('afterparties')
            .where('guestRequests', 'array-contains', { paymentId: paymentId })
            .get();
            
        if (afterpartiesSnapshot.empty) {
            console.log('⚠️ No afterparty found for payment:', paymentId);
            return;
        }
        
        // Process each matching afterparty (should be only one)
        for (const doc of afterpartiesSnapshot.docs) {
            const afterparty = doc.data();
            const guestRequests = afterparty.guestRequests || [];
            
            // Find and update the refunded request
            const updatedRequests = guestRequests.map(req => {
                if (req.paymentId === paymentId) {
                    return {
                        ...req,
                        paymentStatus: 'refunded',
                        refundedAt: admin.firestore.FieldValue.serverTimestamp()
                    };
                }
                return req;
            });
            
            // Remove user from activeUsers
            const userId = guestRequests.find(req => req.paymentId === paymentId)?.userId;
            const activeUsers = (afterparty.activeUsers || []).filter(id => id !== userId);
            
            // Update the afterparty
            await doc.ref.update({
                guestRequests: updatedRequests,
                activeUsers: activeUsers,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            console.log('✅ Refund processed for payment:', paymentId);
        }
    } catch (error) {
        console.error('❌ Error processing refund:', error);
        throw error;
    }
}

// Webhook signature verification function
function verifyWebhookSignature(payload, signature, secret) {
    const crypto = require('crypto');
    
    try {
        // Convert payload to string if it's an object
        const payloadString = typeof payload === 'string' ? payload : JSON.stringify(payload);
        
        // Create expected signature
        const expectedSignature = crypto
            .createHmac('sha256', secret)
            .update(payloadString, 'utf8')
            .digest('hex');
        
        // Compare signatures securely
        const providedSignature = signature.replace('sha256=', '');
        
        return crypto.timingSafeEqual(
            Buffer.from(expectedSignature, 'hex'),
            Buffer.from(providedSignature, 'hex')
        );
    } catch (error) {
        console.error('❌ Error verifying webhook signature:', error);
        return false;
    }
}

// Helper function to send push notifications (implement based on your notification system)
async function sendPaymentSuccessNotification(userId, partyTitle) {
    console.log(`📱 Would send push notification to user ${userId}: Payment successful for ${partyTitle}`);
    // Implement your push notification logic here
}

async function sendPaymentFailedNotification(userId) {
    console.log(`📱 Would send push notification to user ${userId}: Payment failed`);
    // Implement your push notification logic here
} 