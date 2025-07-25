const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');

// Initialize Firebase Admin
admin.initializeApp();

// Export existing chat functions
const { initializeChatData, addChatMessage, endPartyChat } = require('./chatFunctions');
exports.initializeChatData = initializeChatData;
exports.addChatMessage = addChatMessage;
exports.endPartyChat = endPartyChat;

// Export existing Dodo webhook
const { dodoWebhook } = require('./dodoWebhook');
exports.dodoWebhook = dodoWebhook;

// Export NEW FCM notification functions
const { 
    sendPushNotification, 
    sendPushNotificationHTTP, 
    testFCMNotification 
} = require('./fcmNotifications');

exports.sendPushNotification = sendPushNotification;
exports.sendPushNotificationHTTP = sendPushNotificationHTTP;
exports.testFCMNotification = testFCMNotification;

// Export LemonSqueezy webhook function
const { lemonSqueezyWebhook } = require('./lemonSqueezyWebhook');
exports.lemonSqueezyWebhook = lemonSqueezyWebhook;

const GOOGLE_PLACES_API_KEY = functions.config().google.places_key; // Set this in Firebase env
const LEMONSQUEEZY_WEBHOOK_SECRET = functions.config().lemonsqueezy?.webhook_secret; // Set webhook secret

exports.scrapeVenuesForCity = functions.https.onCall(async (data, context) => {
  const city = data.city;
  if (!city) {
    throw new functions.https.HttpsError('invalid-argument', 'City is required');
  }

  const types = ['night_club', 'bar'];
  let venues = [];
  let nextPageToken = null;
  let page = 0;

  do {
    let url = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodeURIComponent(types.join(' OR ') + ' in ' + city)}&key=${GOOGLE_PLACES_API_KEY}`;
    if (nextPageToken) url += `&pagetoken=${nextPageToken}`;

    const res = await axios.get(url);
    if (res.data.status !== 'OK' && res.data.status !== 'ZERO_RESULTS') {
      throw new functions.https.HttpsError('internal', `Google Places error: ${res.data.status}`);
    }
    venues = venues.concat(res.data.results);

    nextPageToken = res.data.next_page_token;
    page++;
    if (nextPageToken) await new Promise(r => setTimeout(r, 2000)); // Google API requires delay
  } while (nextPageToken && page < 3);

  // Filter and map results
  const venueDocs = venues
    .filter(v => v.types.includes('night_club') || v.types.includes('bar'))
    .map(v => ({
      venueId: v.place_id,
      venueName: v.name,
      address: v.formatted_address,
      placeId: v.place_id,
      totalReviews: v.user_ratings_total || 0,
      averageRating: v.rating || 0,
      photoUrl: v.photos && v.photos[0] ? `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${v.photos[0].photo_reference}&key=${GOOGLE_PLACES_API_KEY}` : null,
      location: v.geometry && v.geometry.location ? v.geometry.location : null,
      types: v.types
    }));

  // Write to Firestore
  const batch = admin.firestore().batch();
  const cityKey = city.toLowerCase().replace(/[^a-z0-9]/g, '_');
  const venuesRef = admin.firestore().collection('venues').doc(cityKey).collection('venueList');
  venueDocs.forEach(venue => {
    batch.set(venuesRef.doc(venue.venueId), venue, { merge: true });
  });
  await batch.commit();

  return { count: venueDocs.length, city: cityKey };
});

// MARK: - Dodo Payments Webhook Handler
exports.dodoWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    // Get webhook headers for verification
    const webhookId = req.headers['webhook-id'];
    const webhookSignature = req.headers['webhook-signature'];
    const webhookTimestamp = req.headers['webhook-timestamp'];
    
    console.log('📋 Dodo webhook headers:', {
      id: webhookId,
      signature: webhookSignature,
      timestamp: webhookTimestamp
    });
    
    // Parse the webhook payload
    const event = req.body;
    console.log(`Received Dodo webhook: ${event.event_type}`);
    console.log('📦 Webhook payload:', JSON.stringify(event, null, 2));

    switch (event.event_type) {
      case 'payment.succeeded':
        await handleDodoPaymentSucceeded(event.data);
        break;
      case 'payment.failed':
        await handleDodoPaymentFailed(event.data);
        break;
      case 'refund.succeeded':
        await handleDodoRefundSucceeded(event.data);
        break;
      default:
        console.log(`Unhandled Dodo webhook event: ${event.event_type}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing Dodo webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

// Handle successful Dodo payment
async function handleDodoPaymentSucceeded(data) {
  try {
    const payment = data;
    const metadata = payment.metadata || {};
    const paymentId = payment.payment_id;
    const amount = payment.amount; // Already in dollars, not cents

    if (!metadata) {
      console.error('Missing metadata in Dodo payment success');
      return;
    }

    const { afterpartyId, userId, userName, userHandle, hostId, platformFee, hostEarnings } = metadata;

    if (!userId || !afterpartyId) {
      console.error('Invalid metadata format in Dodo payment success');
      return;
    }

    console.log(`Processing Dodo payment success for user ${userHandle} in afterparty ${afterpartyId}`);

    const db = admin.firestore();
    
    // Get the afterparty document
    const afterpartyRef = db.collection('afterparties').doc(afterpartyId);
    const afterpartyDoc = await afterpartyRef.get();
    
    if (!afterpartyDoc.exists) {
      console.error(`Afterparty ${afterpartyId} not found`);
      return;
    }

    const afterpartyData = afterpartyDoc.data();
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
    if (!activeUsers.includes(userId)) {
      activeUsers.push(userId);
    }

    // Update the afterparty document
    await afterpartyRef.update({
      guestRequests: updatedRequests,
      activeUsers: activeUsers,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Create transaction record with 20% commission
    await db.collection('transactions').add({
      id: paymentId,
      userId: userId,
      afterpartyId: afterpartyId,
      afterpartyTitle: afterpartyData.title,
      amount: amount,
      platformFee: platformFee || (amount * 0.20), // 20% platform fee
      hostEarnings: hostEarnings || (amount * 0.80), // 80% to host
      type: 'purchase',
      status: 'paid',
      dodoPaymentId: paymentId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Send confirmation notification to user
    await sendPaymentConfirmationNotification(userId, afterpartyData.title);

    // Send payment received notification to host
    await notifyHostOfPaymentReceived(hostId, afterpartyData.title, userName, amount);

    console.log(`✅ Successfully processed Dodo payment for payment ${paymentId}`);
  } catch (error) {
    console.error('Error handling Dodo payment success:', error);
  }
}

// Handle failed Dodo payment
async function handleDodoPaymentFailed(data) {
  try {
    const payment = data;
    const metadata = payment.metadata || {};
    const paymentId = payment.payment_id;

    if (!metadata) {
      console.error('Missing metadata in Dodo payment failure');
      return;
    }

    const { afterpartyId, userId } = metadata;

    console.log(`Processing Dodo payment failure for user ${userId} in afterparty ${afterpartyId}`);

    // Send payment failure notification
    await sendPaymentFailureNotification(userId, paymentId);

    console.log(`✅ Successfully processed Dodo payment failure for payment ${paymentId}`);
  } catch (error) {
    console.error('Error handling Dodo payment failure:', error);
  }
}

// Handle Dodo refund
async function handleDodoRefundSucceeded(data) {
  try {
    const refund = data;
    const paymentId = refund.payment_id;
    const refundAmount = refund.amount;
    
    console.log(`Processing Dodo refund for payment ${paymentId}, amount: $${refundAmount}`);

    const db = admin.firestore();
    
    // Find the transaction by Dodo payment ID
    const transactionQuery = await db.collection('transactions')
      .where('dodoPaymentId', '==', paymentId)
      .get();

    if (transactionQuery.empty) {
      console.error(`Transaction not found for Dodo payment ${paymentId}`);
      return;
    }

    const transactionDoc = transactionQuery.docs[0];
    const transactionData = transactionDoc.data();
    
    // Update transaction status
    await transactionDoc.ref.update({
      status: 'refunded',
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      refundAmount: refundAmount
    });

    // Update guest request status in afterparty
    const afterpartyRef = db.collection('afterparties').doc(transactionData.afterpartyId);
    const afterpartyDoc = await afterpartyRef.get();
    
    if (afterpartyDoc.exists) {
      const afterpartyData = afterpartyDoc.data();
      const guestRequests = afterpartyData.guestRequests || [];
      const activeUsers = afterpartyData.activeUsers || [];
      
      const updatedRequests = guestRequests.map(request => {
        if (request.userId === transactionData.userId) {
          return {
            ...request,
            paymentStatus: 'refunded',
            refundedAt: admin.firestore.FieldValue.serverTimestamp()
          };
        }
        return request;
      });

      // Remove user from activeUsers
      const updatedActiveUsers = activeUsers.filter(id => id !== transactionData.userId);

      await afterpartyRef.update({
        guestRequests: updatedRequests,
        activeUsers: updatedActiveUsers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // CRITICAL: Reverse host earnings for this refund
      console.log(`💰 WEBHOOK: Reversing host earnings for refund...`);
      console.log(`Host: ${afterpartyData.userId}, Party: ${transactionData.afterpartyId}, Guest: ${transactionData.userId}`);
      
      try {
        await reverseHostEarningsForRefund(
          afterpartyData.userId, // hostId
          transactionData.afterpartyId, // partyId
          transactionData.userId, // guestId
          refundAmount,
          paymentId
        );
        console.log(`✅ WEBHOOK: Successfully reversed host earnings for refund`);
      } catch (earningsError) {
        console.error(`🔴 WEBHOOK: Failed to reverse host earnings:`, earningsError);
        // Continue processing but log the error for manual intervention
      }
    }

    // Send refund notification
    await sendRefundNotification(transactionData.userId, transactionData.afterpartyTitle);

    console.log(`✅ Successfully processed Dodo refund for payment ${paymentId}`);
  } catch (error) {
    console.error('Error handling Dodo refund:', error);
    throw error;
  }
}

// CRITICAL: Helper function to reverse host earnings
async function reverseHostEarningsForRefund(hostId, partyId, guestId, refundAmount, paymentId) {
  const db = admin.firestore();
  const hostEarningsRef = db.collection('hostEarnings').doc(hostId);
  
  await db.runTransaction(async (transaction) => {
    const hostDoc = await transaction.get(hostEarningsRef);
    
    if (!hostDoc.exists) {
      console.log(`🔴 REVERSAL: No earnings record found for host ${hostId}`);
      return;
    }
    
    const hostEarnings = hostDoc.data();
    const transactions = hostEarnings.transactions || [];
    
    // Find the original transaction to reverse
    let reversalAmount = 0;
    const updatedTransactions = transactions.map(hostTransaction => {
      // Match by partyId and guestId
      if (hostTransaction.partyId === partyId && hostTransaction.guestId === guestId) {
        console.log(`💸 REVERSAL: Found transaction to reverse - Host earning: $${hostTransaction.hostEarning}`);
        reversalAmount = hostTransaction.hostEarning;
        
        // Mark transaction as refunded
        return {
          ...hostTransaction,
          status: 'refunded',
          refundedAt: admin.firestore.FieldValue.serverTimestamp()
        };
      }
      return hostTransaction;
    });
    
    if (reversalAmount === 0) {
      console.log(`🔴 REVERSAL: No matching transaction found to reverse`);
      return;
    }
    
    // Calculate new earnings (reverse the host earning)
    const newPendingEarnings = Math.max(0, hostEarnings.pendingEarnings - reversalAmount);
    const newTotalEarnings = Math.max(0, hostEarnings.totalEarnings - reversalAmount);
    
    console.log(`💸 REVERSAL: Reducing pending earnings by $${reversalAmount}`);
    console.log(`💸 REVERSAL: Old pending: $${hostEarnings.pendingEarnings} → New pending: $${newPendingEarnings}`);
    
    // Update the host earnings
    transaction.update(hostEarningsRef, {
      totalEarnings: newTotalEarnings,
      pendingEarnings: newPendingEarnings,
      transactions: updatedTransactions,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ EARNINGS REVERSAL: Successfully reversed $${reversalAmount} for host ${hostId}`);
  });
}

// MARK: - PayPal Webhook Handler (Legacy)
exports.paypalWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    // Verify webhook signature (PayPal uses different signature verification)
    const paypalSignature = req.headers['paypal-transmission-sig'];
    const transmissionId = req.headers['paypal-transmission-id'];
    const transmissionTime = req.headers['paypal-transmission-time'];
    const body = JSON.stringify(req.body);
    
    // Note: PayPal webhook signature verification would go here
    // For now, we'll process the webhook without verification in development
    
    const { event_type, resource } = req.body;
    
    console.log(`Received PayPal webhook: ${event_type}`);

    switch (event_type) {
      case 'PAYMENT.CAPTURE.COMPLETED':
        await handlePaymentCaptured(resource);
        break;
      case 'PAYMENT.CAPTURE.REFUNDED':
        await handlePaymentRefunded(resource);
        break;
      case 'CHECKOUT.ORDER.APPROVED':
        await handleOrderApproved(resource);
        break;
      default:
        console.log(`Unhandled PayPal webhook event: ${event_type}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing PayPal webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

// Handle successful PayPal payment capture
async function handlePaymentCaptured(resource) {
  try {
    const customId = resource.custom_id;
    const captureId = resource.id;
    const amount = parseFloat(resource.amount?.value || '0');

    if (!customId) {
      console.error('Missing custom_id in PayPal payment capture');
      return;
    }

    // Parse custom_id: "userId|afterpartyId|userHandle"
    const [userId, afterpartyId, userHandle] = customId.split('|');

    if (!userId || !afterpartyId) {
      console.error('Invalid custom_id format in PayPal payment capture');
      return;
    }

    console.log(`Processing PayPal payment capture for user ${userId} in afterparty ${afterpartyId}`);

    const db = admin.firestore();
    
    // Get the afterparty document
    const afterpartyRef = db.collection('afterparties').doc(afterpartyId);
    const afterpartyDoc = await afterpartyRef.get();
    
    if (!afterpartyDoc.exists) {
      console.error(`Afterparty ${afterpartyId} not found`);
      return;
    }

    const afterpartyData = afterpartyDoc.data();
    const guestRequests = afterpartyData.guestRequests || [];
    
    // Find and update the guest request
    const updatedRequests = guestRequests.map(request => {
      if (request.userId === userId) {
        return {
          ...request,
          paymentStatus: 'paid',
          paypalOrderId: captureId,
          paidAt: admin.firestore.FieldValue.serverTimestamp()
        };
      }
      return request;
    });

    // Update the afterparty document
    await afterpartyRef.update({
      guestRequests: updatedRequests
    });

    // Create transaction record
    await db.collection('transactions').add({
      id: captureId,
      userId: userId,
      afterpartyId: afterpartyId,
      afterpartyTitle: afterpartyData.title,
      amount: amount,
      type: 'purchase',
      status: 'paid',
      paypalOrderId: captureId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Send notification to user
    await sendPaymentConfirmationNotification(userId, afterpartyData.title);

    console.log(`✅ Successfully processed PayPal payment for user ${userId}`);
  } catch (error) {
    console.error('Error handling PayPal payment capture:', error);
  }
}

// Handle PayPal payment refund
async function handlePaymentRefunded(resource) {
  try {
    const refundId = resource.id;
    const amount = parseFloat(resource.amount?.value || '0');
    const captureId = resource.links?.find(link => link.rel === 'up')?.href?.split('/').pop();

    console.log(`Processing PayPal refund ${refundId} for capture ${captureId}`);

    const db = admin.firestore();
    
    // Find the transaction by PayPal order ID
    const transactionQuery = await db.collection('transactions')
      .where('paypalOrderId', '==', captureId)
      .get();

    if (transactionQuery.empty) {
      console.error(`Transaction not found for PayPal capture ${captureId}`);
      return;
    }

    const transactionDoc = transactionQuery.docs[0];
    const transactionData = transactionDoc.data();
    
    // Update transaction status
    await transactionDoc.ref.update({
      status: 'refunded',
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      refundAmount: amount
    });

    // Update guest request status in afterparty
    const afterpartyRef = db.collection('afterparties').doc(transactionData.afterpartyId);
    const afterpartyDoc = await afterpartyRef.get();
    
    if (afterpartyDoc.exists) {
      const afterpartyData = afterpartyDoc.data();
      const guestRequests = afterpartyData.guestRequests || [];
      
      const updatedRequests = guestRequests.map(request => {
        if (request.userId === transactionData.userId) {
          return {
            ...request,
            paymentStatus: 'refunded',
            refundedAt: admin.firestore.FieldValue.serverTimestamp()
          };
        }
        return request;
      });

      await afterpartyRef.update({
        guestRequests: updatedRequests
      });
    }

    // Send refund notification
    await sendRefundNotification(transactionData.userId, transactionData.afterpartyTitle);

    console.log(`✅ Successfully processed PayPal refund for capture ${captureId}`);
  } catch (error) {
    console.error('Error handling PayPal refund:', error);
  }
}

// Handle PayPal order approval (user approved but not yet captured)
async function handleOrderApproved(resource) {
  try {
    const orderId = resource.id;
    const customId = resource.purchase_units?.[0]?.custom_id;

    console.log(`PayPal order approved: ${orderId}`);

    if (customId) {
      // Parse custom_id: "userId|afterpartyId|userHandle"
      const [userId, afterpartyId, userHandle] = customId.split('|');
      
      if (userId && afterpartyId) {
        console.log(`Order approved for user ${userId} in afterparty ${afterpartyId} - awaiting capture`);
      }
    }
  } catch (error) {
    console.error('Error handling PayPal order approval:', error);
  }
}

// Send payment confirmation notification
async function sendPaymentConfirmationNotification(userId, afterpartyTitle) {
  try {
    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (fcmToken) {
      const message = {
        notification: {
          title: 'Payment Confirmed! 🎉',
          body: `Your ticket for ${afterpartyTitle} is confirmed!`
        },
        data: {
          type: 'payment_confirmation',
          afterpartyTitle: afterpartyTitle
        },
        token: fcmToken
      };

      await admin.messaging().send(message);
    }
  } catch (error) {
    console.error('Error sending payment confirmation:', error);
  }
}

// Send refund notification
async function sendRefundNotification(userId, afterpartyTitle) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (fcmToken) {
      const message = {
        notification: {
          title: 'Refund Processed 💳',
          body: `Your refund for ${afterpartyTitle} has been processed.`
        },
        data: {
          type: 'refund_notification',
          afterpartyTitle: afterpartyTitle
        },
        token: fcmToken
      };

      await admin.messaging().send(message);
    }
  } catch (error) {
    console.error('Error sending refund notification:', error);
  }
}

// MARK: - Host Payout Functions
exports.processHostPayouts = functions.pubsub.schedule('0 9 * * 1').onRun(async (context) => {
  // Run every Monday at 9 AM to process host payouts
  try {
    const db = admin.firestore();
    const now = new Date();
    const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    // Get completed afterparties from the past week
    const afterpartiesSnapshot = await db.collection('afterparties')
      .where('endTime', '<=', oneWeekAgo)
      .where('payoutProcessed', '==', false)
      .get();

    const batch = db.batch();
    
    for (const doc of afterpartiesSnapshot.docs) {
      const afterparty = doc.data();
      const confirmedGuests = afterparty.guestRequests?.filter(req => req.paymentStatus === 'paid') || [];
      
      if (confirmedGuests.length > 0) {
        const totalRevenue = confirmedGuests.length * afterparty.ticketPrice;
            const hostEarnings = totalRevenue * 0.80; // 80% to host
    const platformFee = totalRevenue * 0.20; // 20% platform fee

        // Create payout record
        const payoutRef = db.collection('payouts').doc();
        batch.set(payoutRef, {
          hostId: afterparty.userId,
          afterpartyId: doc.id,
          afterpartyTitle: afterparty.title,
          totalRevenue: totalRevenue,
          hostEarnings: hostEarnings,
          platformFee: platformFee,
          guestCount: confirmedGuests.length,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Mark afterparty as payout processed
        batch.update(doc.ref, {
          payoutProcessed: true,
          payoutAmount: hostEarnings,
          payoutCreatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }

    await batch.commit();
    console.log(`Processed payouts for ${afterpartiesSnapshot.size} afterparties`);
  } catch (error) {
    console.error('Error processing host payouts:', error);
  }
});

// MARK: - Notification Functions for Dodo Payments

async function sendPaymentConfirmationNotification(userId, partyTitle) {
  try {
    // Get user's FCM token from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: '💳 Payment Confirmed!',
          body: `Your payment for "${partyTitle}" has been processed successfully.`
        },
        data: {
          type: 'payment_confirmed',
          partyTitle: partyTitle
        }
      };

      await admin.messaging().send(message);
      console.log(`✅ Sent payment confirmation notification to user ${userId}`);
    }
  } catch (error) {
    console.error('Error sending payment confirmation notification:', error);
  }
}

async function sendPaymentFailureNotification(userId, intentId) {
  try {
    // Get user's FCM token from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: '❌ Payment Failed',
          body: 'Your payment could not be processed. Please try again.'
        },
        data: {
          type: 'payment_failed',
          intentId: intentId
        }
      };

      await admin.messaging().send(message);
      console.log(`✅ Sent payment failure notification to user ${userId}`);
    }
  } catch (error) {
    console.error('Error sending payment failure notification:', error);
  }
}

async function sendDisputeNotification(disputeId, amount) {
  try {
    // Send admin notification about dispute
    console.log(`⚠️ Admin notification: Dispute ${disputeId} for $${amount}`);
    
    // Here you could send an email or Slack notification to admins
    // For now, just log it
  } catch (error) {
    console.error('Error sending dispute notification:', error);
  }
}

// Helper function to notify host of payment received
async function notifyHostOfPaymentReceived(hostId, partyTitle, guestName, amount) {
  try {
    const hostEarnings = amount * 0.8; // 80% to host
    
    // Get host's FCM tokens
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(hostId)
      .collection('fcmTokens')
      .get();
    
    const tokens = [];
    tokensSnapshot.forEach(doc => {
      const tokenData = doc.data();
      if (tokenData.token) {
        tokens.push(tokenData.token);
      }
    });

    if (tokens.length === 0) {
      const userDoc = await admin.firestore().collection('users').doc(hostId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }

    if (tokens.length > 0) {
      const message = {
        notification: {
          title: '💰 Payment Received!',
          body: `${guestName} paid $${amount} for ${partyTitle}. You earned $${hostEarnings.toFixed(2)}!`
        },
        data: {
          type: 'payment_received',
          partyTitle: partyTitle,
          guestName: guestName,
          amount: amount.toString(),
          hostEarnings: hostEarnings.toFixed(2)
        }
      };

      const promises = tokens.map(token => {
        return admin.messaging().send({ ...message, token });
      });

      await Promise.allSettled(promises);
      console.log(`Sent payment notification to host ${hostId}`);
    }
  } catch (error) {
    console.error('Error notifying host of payment:', error);
  }
}

// MARK: - Analytics and Reporting
exports.generateWeeklyReport = functions.pubsub.schedule('0 10 * * 1').onRun(async (context) => {
  try {
    const db = admin.firestore();
    const now = new Date();
    const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    // Get metrics for the past week
    const transactionsSnapshot = await db.collection('transactions')
      .where('createdAt', '>=', oneWeekAgo)
      .where('type', '==', 'purchase')
      .where('status', '==', 'paid')
      .get();

    const totalRevenue = transactionsSnapshot.docs.reduce((sum, doc) => {
      return sum + (doc.data().amount || 0);
    }, 0);

    const totalTransactions = transactionsSnapshot.size;
    const averageTransactionValue = totalTransactions > 0 ? totalRevenue / totalTransactions : 0;

    // Store weekly report
    await db.collection('analytics').doc(`week_${now.getFullYear()}_${getWeekNumber(now)}`).set({
      weekStart: oneWeekAgo,
      weekEnd: now,
      totalRevenue: totalRevenue,
      totalTransactions: totalTransactions,
      averageTransactionValue: averageTransactionValue,
      generatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Generated weekly report: $${totalRevenue} revenue, ${totalTransactions} transactions`);
  } catch (error) {
    console.error('Error generating weekly report:', error);
  }
});

function getWeekNumber(date) {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const pastDaysOfYear = (date - firstDayOfYear) / 86400000;
  return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
}

// MARK: - Test Push Notification Function
exports.sendTestPushNotification = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  
  try {
    console.log(`Sending test push notification to user: ${userId}`);
    
    console.log(`Looking for FCM tokens for user: ${userId}`);
    
    // Check multiple locations for FCM tokens
    let tokens = [];
    
    // 1. Check new structure: users/{userId}/fcmTokens collection
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('fcmTokens')
      .get();
    
    if (!tokensSnapshot.empty) {
      console.log(`Found ${tokensSnapshot.size} FCM tokens in fcmTokens collection`);
      tokensSnapshot.forEach(doc => {
        const tokenData = doc.data();
        if (tokenData.token) {
          tokens.push(tokenData.token);
        }
      });
    }
    
    // 2. Check old structure: users/{userId} document with fcmToken field
    if (tokens.length === 0) {
      console.log('No FCM tokens found in collection, checking user document...');
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.fcmToken) {
          console.log('Found FCM token in user document');
          tokens.push(userData.fcmToken);
        }
      }
    }
    
    // 3. Check users/{userId}/deviceTokens collection (another possible location)
    if (tokens.length === 0) {
      console.log('Checking deviceTokens collection...');
      const deviceTokensSnapshot = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('deviceTokens')
        .get();
      
      if (!deviceTokensSnapshot.empty) {
        console.log(`Found ${deviceTokensSnapshot.size} device tokens`);
        deviceTokensSnapshot.forEach(doc => {
          const tokenData = doc.data();
          if (tokenData.token) {
            tokens.push(tokenData.token);
          }
        });
      }
    }
    
    if (tokens.length === 0) {
      console.log('No FCM tokens found in any location');
      throw new functions.https.HttpsError('failed-precondition', 'No FCM token found for user');
    }
    
    console.log(`Found ${tokens.length} FCM token(s), sending test notifications...`);
    
    // Send to all tokens
    const promises = tokens.map(token => sendTestNotificationToToken(token));
    await Promise.all(promises);
    
    return { 
      success: true, 
      message: 'Test notification sent!', 
      tokensCount: tokens.length 
    };
    
  } catch (error) {
    console.error('Error sending test push notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

async function sendTestNotificationToToken(fcmToken) {
  const message = {
    notification: {
      title: '🎉 Push Notifications Working!',
      body: 'Great! Your Bondfyr app can receive push notifications.'
    },
    data: {
      type: 'test_notification',
      timestamp: Date.now().toString()
    },
    token: fcmToken
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent test message:', response);
    return response;
  } catch (error) {
    console.error('Error sending test message to token:', fcmToken, error);
    throw error;
  }
}

// MARK: - Party Notification Functions

// Send notification to host when guest requests to join
exports.notifyHostOfGuestRequest = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { hostUserId, partyId, partyTitle, guestName } = data;

  if (!hostUserId || !partyId || !partyTitle || !guestName) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    console.log(`Sending guest request notification to host ${hostUserId}`);
    
    // Get host's FCM tokens
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(hostUserId)
      .collection('fcmTokens')
      .get();
    
    const tokens = [];
    tokensSnapshot.forEach(doc => {
      const tokenData = doc.data();
      if (tokenData.token) {
        tokens.push(tokenData.token);
      }
    });

    // Also check for legacy fcmToken field
    if (tokens.length === 0) {
      const userDoc = await admin.firestore().collection('users').doc(hostUserId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }

    if (tokens.length === 0) {
      console.log(`No FCM tokens found for host ${hostUserId}`);
      return { success: false, message: 'No FCM tokens found' };
    }

    // Send notification to all host's devices
    const message = {
      notification: {
        title: '🔔 New Guest Request',
        body: `${guestName} wants to join ${partyTitle}. Tap to review!`
      },
      data: {
        type: 'host_guest_request',
        partyId: partyId,
        partyTitle: partyTitle,
        guestName: guestName
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

    const promises = tokens.map(token => {
      return admin.messaging().send({ ...message, token });
    });

    const results = await Promise.allSettled(promises);
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    
    console.log(`Sent host notification to ${successCount}/${tokens.length} devices`);
    return { success: true, sentCount: successCount, totalTokens: tokens.length };

  } catch (error) {
    console.error('Error sending host notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Send notification to guest when approved
exports.notifyGuestOfApproval = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { guestUserId, partyId, partyTitle, hostName, amount } = data;

  if (!guestUserId || !partyId || !partyTitle || !amount) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    console.log(`Sending approval notification to guest ${guestUserId}`);
    
    // Get guest's FCM tokens
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(guestUserId)
      .collection('fcmTokens')
      .get();
    
    const tokens = [];
    tokensSnapshot.forEach(doc => {
      const tokenData = doc.data();
      if (tokenData.token) {
        tokens.push(tokenData.token);
      }
    });

    // Also check for legacy fcmToken field
    if (tokens.length === 0) {
      const userDoc = await admin.firestore().collection('users').doc(guestUserId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }

    if (tokens.length === 0) {
      console.log(`No FCM tokens found for guest ${guestUserId}`);
      return { success: false, message: 'No FCM tokens found' };
    }

    // Send notification to all guest's devices
    const message = {
      notification: {
        title: '🎉 Request Approved!',
        body: `You're approved for ${partyTitle}! Complete payment ($${amount}) to secure your spot.`
      },
      data: {
        type: 'guest_approved',
        partyId: partyId,
        partyTitle: partyTitle,
        hostName: hostName || 'Host',
        amount: amount.toString(),
        action: 'show_payment'
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

    const promises = tokens.map(token => {
      return admin.messaging().send({ ...message, token });
    });

    const results = await Promise.allSettled(promises);
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    
    console.log(`Sent guest notification to ${successCount}/${tokens.length} devices`);
    
    // Send follow-up payment reminder after 2 seconds
    setTimeout(async () => {
      const reminderMessage = {
        notification: {
          title: '💳 Payment Required',
          body: `Don't forget to complete your payment for ${partyTitle} - $${amount}`
        },
        data: {
          type: 'payment_reminder',
          partyId: partyId,
          partyTitle: partyTitle
        },
        apns: {
          payload: {
            aps: {
              sound: 'default'
            }
          }
        }
      };

      const reminderPromises = tokens.map(token => {
        return admin.messaging().send({ ...reminderMessage, token });
      });

      await Promise.allSettled(reminderPromises);
      console.log('Sent payment reminder to guest');
    }, 2000);

    return { success: true, sentCount: successCount, totalTokens: tokens.length };

  } catch (error) {
    console.error('Error sending guest notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Send notification to host when payment received
exports.notifyHostOfPayment = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { hostUserId, partyId, partyTitle, guestName, amount } = data;

  if (!hostUserId || !partyId || !partyTitle || !guestName || !amount) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    console.log(`Sending payment notification to host ${hostUserId}`);
    
    // Get host's FCM tokens
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(hostUserId)
      .collection('fcmTokens')
      .get();
    
    const tokens = [];
    tokensSnapshot.forEach(doc => {
      const tokenData = doc.data();
      if (tokenData.token) {
        tokens.push(tokenData.token);
      }
    });

    // Also check for legacy fcmToken field
    if (tokens.length === 0) {
      const userDoc = await admin.firestore().collection('users').doc(hostUserId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }

    if (tokens.length === 0) {
      console.log(`No FCM tokens found for host ${hostUserId}`);
      return { success: false, message: 'No FCM tokens found' };
    }

    const hostEarnings = amount * 0.8; // 80% to host

    // Send notification to all host's devices
    const message = {
      notification: {
        title: '💰 Payment Received!',
        body: `${guestName} paid $${amount} for ${partyTitle}. You earned $${hostEarnings.toFixed(2)}!`
      },
      data: {
        type: 'payment_received',
        partyId: partyId,
        partyTitle: partyTitle,
        guestName: guestName,
        amount: amount.toString(),
        hostEarnings: hostEarnings.toFixed(2)
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

    const promises = tokens.map(token => {
      return admin.messaging().send({ ...message, token });
    });

    const results = await Promise.allSettled(promises);
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    
    console.log(`Sent payment notification to ${successCount}/${tokens.length} devices`);
    return { success: true, sentCount: successCount, totalTokens: tokens.length };

  } catch (error) {
    console.error('Error sending payment notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});